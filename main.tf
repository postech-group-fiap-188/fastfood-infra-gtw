provider "aws" {
  region  = var.region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

# API Gateway
resource "aws_api_gateway_rest_api" "this" {
  name        = "fastfood-api"
  description = "API Gateway com auth e integração com fastfood app"
}

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

# Products System - /fastfood-products-system/api/{proxy+}
resource "aws_api_gateway_resource" "products_system" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "fastfood-products-system"
}

resource "aws_api_gateway_resource" "products_api" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.products_system.id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "products_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.products_api.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "products_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy"           = true
    "method.request.header.Authorization" = false
  }
}

resource "aws_api_gateway_integration" "products_proxy_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products_proxy.id
  http_method             = aws_api_gateway_method.products_proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${var.products_service_url}/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.proxy"           = "method.request.path.proxy"
    "integration.request.header.Authorization" = "method.request.header.Authorization"
  }
}

# Orders System - /fastfood-orders-system/api/{proxy+}
resource "aws_api_gateway_resource" "orders_system" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "fastfood-orders-system"
}

resource "aws_api_gateway_resource" "orders_api" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_system.id
  path_part   = "api"
}

# Rota específica: POST /fastfood-orders-system/api/orders (com autenticação)
resource "aws_api_gateway_resource" "orders_resource" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_api.id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "orders_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_resource.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.token.id

  request_parameters = {
    "method.request.header.Authorization" = false
  }
}

resource "aws_api_gateway_method_response" "orders_post_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.orders_resource.id
  http_method = aws_api_gateway_method.orders_post.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "orders_post_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_resource.id
  http_method             = aws_api_gateway_method.orders_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP"
  uri                     = "${var.orders_service_url}/orders"

  request_templates = {
    "application/json" = <<EOF
    #set($body = $input.path('$'))
    #if($body.containsKey("client"))
        {
          "client": $input.json('$.client'),
          "items": $input.json('$.items')
        }
    #elseif($context.authorizer.clientId && $context.authorizer.cpf)
    {
      "client": {
        "id": "$context.authorizer.clientId",
        "cpf": "$context.authorizer.cpf"
      },
      "items": $input.json('$.items')
    }
    #else
    {
      "items": $input.json('$.items')
    }
    #end
    EOF
  }

  passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_integration_response" "orders_post_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.orders_resource.id
  http_method = aws_api_gateway_method.orders_post.http_method
  status_code = aws_api_gateway_method_response.orders_post_200.status_code

  depends_on = [aws_api_gateway_integration.orders_post_eks]
}

# Proxy genérico para as demais rotas de orders
resource "aws_api_gateway_resource" "orders_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_api.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "orders_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy"           = true
    "method.request.header.Authorization" = false
  }
}

resource "aws_api_gateway_integration" "orders_proxy_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_proxy.id
  http_method             = aws_api_gateway_method.orders_proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${var.orders_service_url}/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.proxy"           = "method.request.path.proxy"
    "integration.request.header.Authorization" = "method.request.header.Authorization"
  }
}

# Payment System - /fastfood-payment-system/api/{proxy+}
resource "aws_api_gateway_resource" "payment_system" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "fastfood-payment-system"
}

resource "aws_api_gateway_resource" "payment_api" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.payment_system.id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "payment_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.payment_api.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "payment_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.payment_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy"           = true
    "method.request.header.Authorization" = false
  }
}

resource "aws_api_gateway_integration" "payment_proxy_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.payment_proxy.id
  http_method             = aws_api_gateway_method.payment_proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${var.payments_service_url}/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.proxy"           = "method.request.path.proxy"
    "integration.request.header.Authorization" = "method.request.header.Authorization"
  }
}

# Kitchen System - /fastfood-kitchen-system/api/{proxy+}
resource "aws_api_gateway_resource" "kitchen_system" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "fastfood-kitchen-system"
}

resource "aws_api_gateway_resource" "kitchen_api" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.kitchen_system.id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "kitchen_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.kitchen_api.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "kitchen_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.kitchen_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy"           = true
    "method.request.header.Authorization" = false
  }
}

resource "aws_api_gateway_integration" "kitchen_proxy_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.kitchen_proxy.id
  http_method             = aws_api_gateway_method.kitchen_proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${var.kitchen_service_url}/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.proxy"           = "method.request.path.proxy"
    "integration.request.header.Authorization" = "method.request.header.Authorization"
  }
}

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
      aws_api_gateway_method.auth_post.id,
      aws_api_gateway_integration.auth_lambda.id,
      aws_api_gateway_resource.products_system.id,
      aws_api_gateway_resource.products_api.id,
      aws_api_gateway_resource.products_proxy.id,
      aws_api_gateway_method.products_proxy_any.id,
      aws_api_gateway_integration.products_proxy_eks.id,
      aws_api_gateway_resource.orders_system.id,
      aws_api_gateway_resource.orders_api.id,
      aws_api_gateway_resource.orders_resource.id,
      aws_api_gateway_method.orders_post.id,
      aws_api_gateway_integration.orders_post_eks.id,
      aws_api_gateway_resource.orders_proxy.id,
      aws_api_gateway_method.orders_proxy_any.id,
      aws_api_gateway_integration.orders_proxy_eks.id,
      aws_api_gateway_resource.payment_system.id,
      aws_api_gateway_resource.payment_api.id,
      aws_api_gateway_resource.payment_proxy.id,
      aws_api_gateway_method.payment_proxy_any.id,
      aws_api_gateway_integration.payment_proxy_eks.id,
      aws_api_gateway_resource.kitchen_system.id,
      aws_api_gateway_resource.kitchen_api.id,
      aws_api_gateway_resource.kitchen_proxy.id,
      aws_api_gateway_method.kitchen_proxy_any.id,
      aws_api_gateway_integration.kitchen_proxy_eks.id,
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

# Permissões para o API Gateway invocar as Lambdas
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
