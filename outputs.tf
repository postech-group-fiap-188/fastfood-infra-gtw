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
    auth     = "https://${aws_api_gateway_domain_name.fiap.domain_name}/auth"
    products = "https://${aws_api_gateway_domain_name.fiap.domain_name}/fastfood-products-system/api"
    orders   = "https://${aws_api_gateway_domain_name.fiap.domain_name}/fastfood-orders-system/api"
    payments = "https://${aws_api_gateway_domain_name.fiap.domain_name}/fastfood-payment-system/api"
    kitchen  = "https://${aws_api_gateway_domain_name.fiap.domain_name}/fastfood-kitchen-system/api"
  }
}
