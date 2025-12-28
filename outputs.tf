output "api_gateway_url" {
  description = "URL base do API Gateway"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "api_gateway_id" {
  description = "ID do API Gateway"
  value       = aws_api_gateway_rest_api.this.id
}

output "endpoints" {
  description = "Endpoints disponíveis no API Gateway"
  value = {
    auth     = "${aws_api_gateway_stage.prod.invoke_url}/auth"
    products = "${aws_api_gateway_stage.prod.invoke_url}/fastfood-products-system/api"
    orders   = "${aws_api_gateway_stage.prod.invoke_url}/fastfood-orders-system/api"
    payments = "${aws_api_gateway_stage.prod.invoke_url}/fastfood-payment-system/api"
    kitchen  = "${aws_api_gateway_stage.prod.invoke_url}/fastfood-kitchen-system/api"
  }
}
