# envs/dev/main.tf

provider "aws" {
  region = "eu-central-1"
}

locals {
  prefix = "nechyporuk-ira-13"
}

module "database" {
  source     = "../../modules/dynamodb"
  table_name = "${local.prefix}-telemetry"
}

module "queue" {
  source             = "../../modules/sqs"
  queue_name         = "${local.prefix}-telemetry-queue"
  visibility_timeout = 60
  max_receive_count  = 3
}

module "producer" {
  source            = "../../modules/lambda"
  function_name     = "${local.prefix}-producer"
  source_file       = "${path.root}/../../src/api_handler.py"
  handler           = "api_handler.handler"
  sqs_queue_arn     = module.queue.queue_arn
  attach_sqs_policy = true

  environment_vars = {
    QUEUE_URL = module.queue.queue_url
  }
}

module "consumer" {
  source                 = "../../modules/lambda"
  function_name          = "${local.prefix}-consumer"
  source_file            = "${path.root}/../../src/sqs_processor.py"
  handler                = "sqs_processor.handler"
  dynamodb_table_arn     = module.database.table_arn
  sqs_queue_arn          = module.queue.queue_arn
  sqs_source_arn         = module.queue.queue_arn
  enable_sqs_trigger     = true
  sqs_batch_size         = 10
  sqs_batching_window    = 5  # Залишаємо 5 секунд для збору пачки!
  concurrency            = -1 # ЗМІНЕНО: повертаємо безліміт, щоб уникнути Throttling
  attach_dynamodb_policy = true
  attach_sqs_policy      = true

  environment_vars = {
    TABLE_NAME = module.database.table_name
  }
}

module "getter" {
  source                 = "../../modules/lambda"
  function_name          = "${local.prefix}-getter"
  source_file            = "${path.root}/../../src/get_handler.py"
  handler                = "get_handler.handler"
  dynamodb_table_arn     = module.database.table_arn
  attach_dynamodb_policy = true

  environment_vars = {
    TABLE_NAME = module.database.table_name
  }
}

module "api" {
  source                 = "../../modules/api_gateway"
  api_name               = "${local.prefix}-iot-api"
  producer_invoke_arn    = module.producer.invoke_arn
  producer_function_name = module.producer.function_name
  getter_invoke_arn      = module.getter.invoke_arn
  getter_function_name   = module.getter.function_name
}

output "api_url" {
  value       = module.api.api_endpoint
  description = "Base URL for the IoT Telemetry API"
}

output "queue_url" {
  value = module.queue.queue_url
}