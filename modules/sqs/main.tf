# modules/sqs/main.tf

variable "queue_name" {
  type = string
}

variable "visibility_timeout" {
  type    = number
  default = 60
}

variable "max_receive_count" {
  type    = number
  default = 3
}

# Dead-Letter Queue — отримує повідомлення після 3 невдалих спроб
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.queue_name}-dlq"
  message_retention_seconds = 1209600 # 14 днів

  tags = {
    Purpose = "DLQ for ${var.queue_name}"
  }
}

# Основна черга
resource "aws_sqs_queue" "main" {
  name                       = var.queue_name
  visibility_timeout_seconds = var.visibility_timeout
  message_retention_seconds  = 86400 # 1 день

  # Прив'язка DLQ: після max_receive_count невдалих обробок -> DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Purpose = "IoT telemetry buffer"
  }
}

output "queue_url" {
  value = aws_sqs_queue.main.url
}

output "queue_arn" {
  value = aws_sqs_queue.main.arn
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}