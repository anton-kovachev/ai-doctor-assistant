output "api_gateway_url" {
  description = "The URL of the API Gateway"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "app_lambda_function_url" {
  description = "The URL of the app Lambda function"
  value       = aws_lambda_function_url.app_lambda_url.function_url
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.doctor_assistant_repo.repository_url
}

output "frontend_bucket_name" {
  description = "Name of the S3 bucket hosting the frontend"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_website_url" {
  description = "URL of the S3 static website"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "frontend_clerk_publishable_key" {
  description = "Clerk publishable key required to build the frontend"
  value       = var.next_public_clerk_publishable_key
  sensitive   = true
}

output "redis_primary_endpoint" {
  description = "ElastiCache primary endpoint for the selected environment"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}
