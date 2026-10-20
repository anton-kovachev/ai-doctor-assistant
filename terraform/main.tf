data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  app_hash = sha256(jsonencode({
    dockerfile   = filesha256("${path.module}/${var.app_dir}/Dockerfile")
    dockerignore = filesha256("${path.module}/${var.app_dir}/.dockerignore")
    backend = {
      for file in fileset("${path.module}/${var.app_dir}/backend/api", "**") :
      file => filesha256("${path.module}/${var.app_dir}/backend/api/${file}")
      if !contains(split("/", file), "__pycache__") && !contains(split("/", file), "node_modules")
    }
    requirements = filesha256("${path.module}/${var.app_dir}/backend/requirements.txt")
  }))
}

# S3 bucket for the statically exported frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name_prefix}-frontend-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

resource "aws_ecr_repository" "doctor_assistant_repo" {
  name                 = "${local.name_prefix}-${var.ecr_repository_name}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "random_id" "app_rand_tag" {
  keepers = {
    app_img_hash = local.app_hash
  }

  byte_length = 2
}

resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name_prefix}-api-gateway"
  protocol_type = "HTTP"
  tags          = local.common_tags

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["*"]
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_origins     = ["*"]
    max_age           = 300
  }
}

resource "null_resource" "build_and_push_app_image" {
  triggers = {
    app_hash = local.app_hash
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module
    command     = <<-EOT
        docker build --progress=plain -t ${local.name_prefix}-${var.ecr_repository_name}:${random_id.app_rand_tag.hex} ${var.app_dir} --platform linux/amd64 --provenance false --no-cache
        aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
        docker tag ${local.name_prefix}-${var.ecr_repository_name}:${random_id.app_rand_tag.hex} ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.name_prefix}-${var.ecr_repository_name}:${random_id.app_rand_tag.hex}
        docker push ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.name_prefix}-${var.ecr_repository_name}:${random_id.app_rand_tag.hex}
        EOT
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"
  tags = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "app_lambda_secrets" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          data.aws_secretsmanager_secret.openrouter.arn,
          data.aws_secretsmanager_secret.openai.arn,
          data.aws_secretsmanager_secret.anthropic.arn,
          data.aws_secretsmanager_secret.email_password.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_bedrock" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_lambda_function" "app_lambda" {
  function_name = "${local.name_prefix}-app-lambda"
  role          = aws_iam_role.lambda_role.arn
  tags          = local.common_tags
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.doctor_assistant_repo.repository_url}:${random_id.app_rand_tag.hex}"
  memory_size   = 512
  timeout       = 60
  depends_on    = [aws_iam_role_policy_attachment.lambda_basic_execution, aws_iam_role_policy_attachment.lambda_bedrock, aws_iam_role_policy_attachment.lambda_s3, null_resource.build_and_push_app_image]
  # Prefer referencing Secrets Manager secrets by name/ARN.
  # Store secret values in AWS Secrets Manager and provide their names
  # via the variables `openrouter_secret_name`, `openai_secret_name`,
  # `anthropic_secret_name`, and `email_app_password_secret_name`.
  # The Lambda will receive the secret ARNs as env vars; the app should
  # fetch the secret values at runtime using the AWS SDK.
  environment {
    variables = {
      CLERK_SECRET_KEY              = "${var.clerk_secret_key}"
      CLERK_JWKS_URL                = "${var.clerk_jwks_url}"
      DEFAULT_AWS_REGION            = "${var.default_aws_region}"
      AWS_ACCOUNT_ID                = "${var.aws_account_id}"
      PROJECT_ID                    = "${var.project_id}"
      AWS_BEDROCK_BASE_URL          = "${var.aws_bedrock_base_url}"
      OPENAI_API_KEY_SECRET_ARN     = "${data.aws_secretsmanager_secret.openai.arn}"
      EMAIL_SMTP_SERVER             = "${var.email_smtp_server}"
      EMAIL_APP_PASSWORD_SECRET_ARN = "${data.aws_secretsmanager_secret.email_password.arn}"
      EMAIL_ADDRESS                 = "${var.email_address}"
    }
  }
}

data "aws_secretsmanager_secret" "openrouter" {
  name = var.openrouter_secret_name
}

data "aws_secretsmanager_secret" "openai" {
  name = var.openai_secret_name
}

data "aws_secretsmanager_secret" "anthropic" {
  name = var.anthropic_secret_name
}

data "aws_secretsmanager_secret" "email_password" {
  name = var.email_app_password_secret_name
}

resource "aws_lambda_function_url" "app_lambda_url" {
  function_name      = aws_lambda_function.app_lambda.function_name
  authorization_type = "NONE"
  invoke_mode        = "RESPONSE_STREAM"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
  tags        = local.common_tags

  default_route_settings {
    throttling_burst_limit = var.api_throttle_burst_limit
    throttling_rate_limit  = var.api_throttle_rate_limit
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.app_lambda.invoke_arn
  depends_on       = [aws_lambda_function.app_lambda, aws_apigatewayv2_api.main]
}

# API Gateway Routes
resource "aws_apigatewayv2_route" "get_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /api"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "consultation_chat" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /api/consultation"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_health" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /api/health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "function_url" {
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.app_lambda.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "function_url_invoke" {
  statement_id             = "AllowPublicFunctionUrlInvoke"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.app_lambda.function_name
  principal                = "*"
  invoked_via_function_url = true
}
