# modules/api_gateway/main.tf

variable "api_name" {
  type = string
}

variable "producer_invoke_arn" {
  type = string
}

variable "producer_function_name" {
  type = string
}

variable "getter_invoke_arn" {
  type = string
}

variable "getter_function_name" {
  type = string
}

# 1. Створення HTTP API (v2) — легша та дешевша альтернатива REST API
resource "aws_apigatewayv2_api" "http_api" {
  name          = var.api_name
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

# 2. Stage $default з автоматичним деплоєм
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# 3. Інтеграція для Producer Lambda (POST /telemetry)
resource "aws_apigatewayv2_integration" "producer" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = var.producer_invoke_arn
}

# 4. Маршрут POST /telemetry
resource "aws_apigatewayv2_route" "post_telemetry" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /telemetry"
  target    = "integrations/${aws_apigatewayv2_integration.producer.id}"
}

# 5. Інтеграція для Getter Lambda (GET /telemetry/{device_id}/latest)
resource "aws_apigatewayv2_integration" "getter" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = var.getter_invoke_arn
}

# 6. Маршрут GET /telemetry/{device_id}/latest
resource "aws_apigatewayv2_route" "get_telemetry" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /telemetry/{device_id}/latest"
  target    = "integrations/${aws_apigatewayv2_integration.getter.id}"
}

# 7. Дозволи для API Gateway на виклик Lambda функцій
resource "aws_lambda_permission" "producer_permission" {
  statement_id  = "AllowAPIGatewayProducer"
  action        = "lambda:InvokeFunction"
  function_name = var.producer_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "getter_permission" {
  statement_id  = "AllowAPIGatewayGetter"
  action        = "lambda:InvokeFunction"
  function_name = var.getter_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}