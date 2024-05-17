resource "random_id" "id" {
          byte_length = 8
}

resource "aws_iam_role" "lambda_execution_role" {
        name = "prisma-cloud-key-rolling-${random_id.id.hex}"
        description = "Lambda execution role for Prisma Cloud secret rotation function"
        assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Sid    = ""
                Principal = {
                  Service = "lambda.amazonaws.com"
                }
          },
        ]
        })

        managed_policy_arns = [ "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" ]

        inline_policy {
                name   = "SecretsManagerRotation"
                policy = jsonencode({
                Version = "2012-10-17"
                Statement = [
                  {
                        Effect = "Allow"
                        Action = [ "secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecretVersionStage" ]
                        Resource = "${aws_secretsmanager_secret.prisma_cloud_secret.id}"
                  }
                ]
                })
        }
}

resource "aws_secretsmanager_secret_rotation" "rotation_schedule" {
  secret_id           = aws_secretsmanager_secret.prisma_cloud_secret.id
  rotation_lambda_arn = aws_lambda_function.secrets_rotation_function.arn
  
  rotation_rules {
    automatically_after_days = var.rotation_interval
        duration = "4h"
  }
}

resource "aws_lambda_permission" "allow_secrets_manager" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secrets_rotation_function.function_name
  principal     = "secretsmanager.amazonaws.com"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir = "${path.module}/lambda/"
  output_path = "lambda_function_payload_${random_id.id.hex}.zip"
}

resource "aws_lambda_function" "secrets_rotation_function" {
  filename      = data.archive_file.lambda.output_path
  function_name = "prisma-cloud-key-roller-${random_id.id.hex}"
  description   = "Lambda function to roll Prisma Cloud Access Keys"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime               = "python3.10"
  timeout               = 20
  memory_size   = 128
  layers                = [ aws_lambda_layer_version.python_sdk_layer.arn ]
}

resource "aws_lambda_layer_version" "python_sdk_layer" {
  layer_name = "prisma-cloud-python-sdk-layer-${random_id.id.hex}"
  description = "Python SDK for Prisma Cloud - https://github.com/PaloAltoNetworks/prismacloud-api-python"
  s3_bucket = "${var.s3_bucket_for_layer}"
  s3_key = "${var.s3_key_for_layer}"
  compatible_runtimes = ["python3.10"]
  compatible_architectures = ["x86_64"]
}

resource "aws_secretsmanager_secret" "prisma_cloud_secret" {
  name = "${var.secret_name}"
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.prisma_cloud_secret.id
  secret_string = jsonencode({ "PRISMA_CLOUD_USER" = "${var.initial_access_key}", "PRISMA_CLOUD_PASS" = "${var.initial_secret_key}", "PRISMA_CLOUD_CONSOLE_URL" = "${var.prisma_cloud_console_url}" } )
}
