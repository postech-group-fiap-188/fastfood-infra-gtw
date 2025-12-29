provider "aws" {
  region  = var.region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

# --- CUSTOM DOMAIN CONFIGURATION ---
resource "aws_api_gateway_domain_name" "fiap" {
  domain_name              = "fiap-lab.com.br"
  regional_certificate_arn = "arn:aws:acm:us-east-1:106185763495:certificate/2360e582-1bf2-47ec-b711-8c388ea36f73"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# --- API GATEWAY ---
resource "aws_api_gateway_rest_api" "this" {
  name        = "fastfood-api"
  description = "API Gateway com auth e integração com fastfood app"
}

resource "aws_api_gateway_base_path_mapping" "fiap_mapping" {
  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  domain_name = aws_api_gateway_domain_name.fiap.domain_name
}

# --- AUTH RESOURCES ---
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.auth.id
  http_method             = aws_api_gateway_method.auth_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.auth_lambda_invoke_arn
}

resource "aws_api_gateway_authorizer" "token" {
  name                             = "bearer-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.this.id
  type                             = "REQUEST"
  identity_source                  = "context.httpMethod,context.resourcePath"
  authorizer_uri                   = var.authorizer_lambda_invoke_arn
  authorizer_result_ttl_in_seconds = 0
}

# --- PRODUCTS SYSTEM ---
resource "aws_api_gateway_resource" "products_system" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "fastfood-products-system"
}

resource "aws_api_gateway_resource" "products_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.products_system.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "products_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "products_proxy_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products_proxy.id
  http_method             = aws_api_gateway_method.products_proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${var.products_service_url}/fastfood-products-system/{proxy}"

  request_parameters = {
    "integration.request.path.proxy"  = "method.request.path.proxy"
    "integration.request.header.Host" = "'fiap-lab.com.br'"
  }
}

# --- ORDERS SYSTEM ---
resource "aws_api_gateway_resource" "orders_system" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "fastfood-orders-system"
}

resource "aws_api_gateway_resource" "orders_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_system.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "orders_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "orders_proxy_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_proxy.id
  http_method             = aws_api_gateway_method.orders_proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${var.orders_service_url}/fastfood-orders-system/{proxy}"

  request_parameters = {
    "integration.request.path.proxy"  = "method.request.path.proxy"
    "integration.request.header.Host" = "'fiap-lab.com.br'"
  }
}

# Rota especial para o POST de Orders com o Authorizer
resource "aws_api_gateway_resource" "orders_root" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_system.id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "orders_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_root.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.token.id
}

resource "aws_api_gateway_integration" "orders_post_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_root.id
  http_method             = aws_api_gateway_method.orders_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "${var.orders_service_url}/fastfood-orders-system/orders"

  request_parameters = {
    "integration.request.header.Host" = "'fiap-lab.com.br'"
  }
}

# --- PAYMENT SYSTEM ---
resource "aws_api_gateway_resource" "payment_system" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "fastfood-payment-system"
}

resource "aws_api_gateway_resource" "payment_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.payment_system.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "payment_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.payment_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "payment_proxy_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.payment_proxy.id
  http_method             = aws_api_gateway_method.payment_proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${var.payments_service_url}/fastfood-payment-system/{proxy}"

  request_parameters = {
    "integration.request.path.proxy"  = "method.request.path.proxy"
    "integration.request.header.Host" = "'fiap-lab.com.br'"
  }
}

# --- KITCHEN SYSTEM ---
resource "aws_api_gateway_resource" "kitchen_system" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "fastfood-kitchen-system"
}

resource "aws_api_gateway_resource" "kitchen_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.kitchen_system.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "kitchen_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.kitchen_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "kitchen_proxy_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.kitchen_proxy.id
  http_method             = aws_api_gateway_method.kitchen_proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${var.kitchen_service_url}/fastfood-kitchen-system/{proxy}"

  request_parameters = {
    "integration.request.path.proxy"  = "method.request.path.proxy"
    "integration.request.header.Host" = "'fiap-lab.com.br'"
  }
}

# --- DEPLOYMENT & STAGE ---
resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    aws_api_gateway_integration.auth_lambda,
    aws_api_gateway_integration.products_proxy_eks,
    aws_api_gateway_integration.orders_post_eks,
    aws_api_gateway_integration.orders_proxy_eks,
    aws_api_gateway_integration.payment_proxy_eks,
    aws_api_gateway_integration.kitchen_proxy_eks
  ]
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.auth.id,
      aws_api_gateway_resource.products_proxy.id,
      aws_api_gateway_resource.orders_proxy.id,
      aws_api_gateway_resource.payment_proxy.id,
      aws_api_gateway_resource.kitchen_proxy.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name
}

# --- PERMISSIONS ---
resource "aws_lambda_permission" "allow_api_gateway_auth" {
  statement_id  = "AllowAPIGatewayInvokeAuth"
  action        = "lambda:InvokeFunction"
  function_name = regex("function:([^/]+)", var.auth_lambda_invoke_arn)[0]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = regex("function:([^/]+)", var.authorizer_lambda_invoke_arn)[0]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*"
}
