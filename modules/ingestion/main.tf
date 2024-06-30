resource "aws_iam_role" "lambda_s3_role" {
  name = "lambda_s3_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_full_access_policy" {
  name        = "s3_full_access_policy"
  description = "A policy that grants full access to S3"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:*"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_full_access" {
  role       = aws_iam_role.lambda_s3_role.name
  policy_arn = aws_iam_policy.s3_full_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda_collect_price_zip" {
  type        = "zip"
  source_dir = "modules/ingestion/lambda/scripts/collect_prices"
  output_path = "collect_prices.zip"
}

resource "aws_lambda_function" "create_jobs_lambda" {
  filename      = data.archive_file.lambda_collect_price_zip.output_path
  function_name = "collect_prices"
  role          = aws_iam_role.lambda_s3_role.arn
  handler       = "collect_prices.lambda_handler"
  runtime       = "python3.11"
  source_code_hash = data.archive_file.lambda_collect_price_zip.output_base64sha256
  timeout       = 300

  environment {
    variables = {
        raw_bucket_name = var.raw_bucket_name
        username = var.username
    }
  }
}