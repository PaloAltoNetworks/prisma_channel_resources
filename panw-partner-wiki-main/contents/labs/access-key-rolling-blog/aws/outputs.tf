output "lambda_execution_role_arn" {
  description = "ARN of the lambda execution role - update for additional secrets if desired"
  value       = aws_iam_role.lambda_execution_role.arn
}
