data "aws_caller_identity" "current" {}

locals {
   name_prefix = "${var.project_name}-${var.environment}"

   common_tags = {
       Project =     var.project_name
       Environment = var.environment
       ManagedBy   = "terraform"
   }

   app_hash  = filebase64sha256("${var.app_dir}/Dockerfile")
}

resource "aws_ecr_repository" "doctor_assistant_repo" {
    name                 = "${local.name_prefix}-${var.ecr_repository_name}"
    image_tag_mutability = "MUTABLE"
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

resource "null_resource" "build_and_push_app_image" {
    triggers = {
        dockerfile_hash = local.app_hash
    }

    provisioner  "local-exec" {
        interpreter = ["/bin/bash", "-c"]
        working_dir = "${path.module}"
        command = <<-EOT
        source set -a && .${path.module}${var.app_dir}/.env && set +a
        docker build -t ${local.name_prefix}-${var.ecr_repository_name}:${random_id.app_rand_tag.hex} ${var.app_dir} --platform linux/amd64 --provenance false --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="${var.next_public_clerk_publishable_key}" 
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
    depends_on    = [aws_iam_role_policy_attachment.lambda_basic_execution, aws_iam_role_policy_attachment.lambda_bedrock, aws_iam_role_policy_attachment.lambda_s3, null_resource.build_and_push_app_image]
    environment {
        variables = {
            CLERK_SECRET_KEY = "${var.clerk_secret_key}"
            CLERK_JWKS_URL   = "${var.clerk_jwks_url}"
            DEFAULT_AWS_REGION = "${var.default_aws_region}"
            AWS_ACCOUNT_ID = "${var.aws_account_id}"
            OPENROUTER_API_KEY = "${var.openrouter_api_key}"
            OPENROUTER_BASE_URL = "${var.openrouter_base_url}"
            OPENAI_API_KEY = "${var.openai_api_key}"
            ANTHROPIC_BASE_URL = "${var.anthropic_base_url}"
            ANTHROPIC_API_KEY = "${var.anthropic_api_key}"
            EMAIL_SMTP_SERVER = "${var.email_smtp_server}"
            EMAIL_APP_PASSWORD = "${var.email_app_password}"
            EMAIL_ADDRESS = "${var.email_address}"
        }
    }
}

resource "aws_lambda_function_url" "app_lambda_url" {
    function_name = aws_lambda_function.app_lambda.function_name
    authorization_type = "NONE"
    invoke_mode        = "RESPONSE_STREAM"
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
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "post_chat" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /chat"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_health" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /health"
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
