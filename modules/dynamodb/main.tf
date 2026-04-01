# modules/dynamodb/main.tf

variable "table_name" {
  description = "Unique name of the DynamoDB table"
  type        = string
}

resource "aws_dynamodb_table" "telemetry" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST" # Без виділеної пропускної здатності
  hash_key     = "device_id"       # Partition Key — ID пристрою
  range_key    = "window_start"    # Sort Key — початок хвилинного вікна

  attribute {
    name = "device_id"
    type = "S" # String
  }

  attribute {
    name = "window_start"
    type = "S" # String (ISO 8601 формат)
  }

  tags = {
    Environment = "dev"
    Purpose     = "IoT telemetry buffer"
  }
}

output "table_name" {
  value = aws_dynamodb_table.telemetry.name
}

output "table_arn" {
  value = aws_dynamodb_table.telemetry.arn
}