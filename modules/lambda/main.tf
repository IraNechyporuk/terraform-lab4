# modules/lambda/main.tf

variable "function_name" {
  type = string
}

variable "source_file" {
  type = string
}

variable "handler" {
  type    = string
  default = "handler.handler"
}

variable "environment_vars" {
  type    = map(string)
  default = {}
}

variable "dynamodb_table_arn" {
  type    = string
  default = ""
}

variable "sqs_queue_arn" {
  type    = string
  default = ""
}

variable "sqs_source_arn" {
  type    = string
  default = ""
}

variable "enable_sqs_trigger" {
  type    = bool
  default = false
}

variable "sqs_batch_size" {
  type    = number
  default = 10
}

variable "sqs_batching_window" {
  type    = number
  default = 0
}

variable "attach_dynamodb_policy" {
  type    = bool
  default = false
}

variable "attach_sqs_policy" {
  type    = bool
  default = false
}

variable "concurrency" {
  type    = number
  default = -1 # -1 = необмежена паралельність
}

# ── ZIP архів з вихідним кодом ──────────────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = var.source_file
  output_path = "${path.module}/${var.function_name}.zip"
}

# ── IAM роль для Lambda ──────────────────────────────────────────────────────
resource "aws_iam_role" "exec" {
  name = "${var.function_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ВИПРАВЛЕННЯ: додано dynamodb:UpdateItem — потрібен для атомарного update_item
resource "aws_iam_role_policy" "dynamodb" {
  count = var.attach_dynamodb_policy ? 1 : 0
  name  = "dynamodb-policy"
  role  = aws_iam_role.exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem", # ← ДОДАНО: потрібен для sqs_processor
        "dynamodb:Query",
        "dynamodb:Scan",
      ]
      Resource = var.dynamodb_table_arn
    }]
  })
}

resource "aws_iam_role_policy" "sqs" {
  count = var.attach_sqs_policy ? 1 : 0
  name  = "sqs-policy"
  role  = aws_iam_role.exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
      ]
      Resource = var.sqs_queue_arn
    }]
  })
}

# ── Lambda функція ───────────────────────────────────────────────────────────
resource "aws_lambda_function" "fn" {
  filename                       = data.archive_file.lambda_zip.output_path
  function_name                  = var.function_name
  role                           = aws_iam_role.exec.arn
  handler                        = var.handler
  runtime                        = "python3.12"
  source_code_hash               = data.archive_file.lambda_zip.output_base64sha256
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = var.concurrency

  environment {
    variables = var.environment_vars
  }
}

# ── SQS тригер (лише для consumer) ──────────────────────────────────────────
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  count                              = var.enable_sqs_trigger ? 1 : 0
  event_source_arn                   = var.sqs_source_arn
  function_name                      = aws_lambda_function.fn.arn
  batch_size                         = var.sqs_batch_size
  maximum_batching_window_in_seconds = var.sqs_batching_window
  enabled                            = true
}

# ── Outputs ──────────────────────────────────────────────────────────────────
output "invoke_arn" {
  value = aws_lambda_function.fn.invoke_arn
}

output "function_name" {
  value = aws_lambda_function.fn.function_name
}

output "function_arn" {
  value = aws_lambda_function.fn.arn
}
