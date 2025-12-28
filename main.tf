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

resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "orders_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.token.id

  request_parameters = {
    "method.request.header.Authorization" = false
  }
}

resource "aws_api_gateway_method_response" "orders_post_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.orders_post.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "orders_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.orders_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP"
  uri                     = "${var.eks_service_url}/v1/orders"

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
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.orders_post.http_method
  status_code = aws_api_gateway_method_response.orders_post_200.status_code

  depends_on = [aws_api_gateway_integration.orders_eks]
}

# GET /orders
resource "aws_api_gateway_method" "orders_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "orders_get_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.orders_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "${var.orders_service_url}/orders"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

# Orders ID Resource
resource "aws_api_gateway_resource" "orders_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders.id
  path_part   = "{id}"
}

# GET /orders/{id}
resource "aws_api_gateway_method" "orders_id_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_id.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "orders_id_get_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_id.id
  http_method             = aws_api_gateway_method.orders_id_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "${var.orders_service_url}/orders/{id}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

# Payments Resource
resource "aws_api_gateway_resource" "payments" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "payments"
}

resource "aws_api_gateway_resource" "payments_checkout" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.payments.id
  path_part   = "checkout"
}

# POST /payments/checkout
resource "aws_api_gateway_method" "payments_checkout_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.payments_checkout.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "payments_checkout_post_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.payments_checkout.id
  http_method             = aws_api_gateway_method.payments_checkout_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "${var.payments_service_url}/payments/checkout"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_resource" "payments_status" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.payments.id
  path_part   = "status"
}

resource "aws_api_gateway_resource" "payments_status_orderid" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.payments_status.id
  path_part   = "{orderId}"
}

# GET /payments/status/{orderId}
resource "aws_api_gateway_method" "payments_status_orderid_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.payments_status_orderid.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.orderId" = true
  }
}

resource "aws_api_gateway_integration" "payments_status_orderid_get_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.payments_status_orderid.id
  http_method             = aws_api_gateway_method.payments_status_orderid_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "${var.payments_service_url}/payments/status/{orderId}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.orderId" = "method.request.path.orderId"
  }
}

# Webhook Resource
resource "aws_api_gateway_resource" "webhook" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "webhook"
}

resource "aws_api_gateway_resource" "webhook_mercadopago" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.webhook.id
  path_part   = "mercadopago"
}

# POST /webhook/mercadopago
resource "aws_api_gateway_method" "webhook_mercadopago_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.webhook_mercadopago.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "webhook_mercadopago_post_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.webhook_mercadopago.id
  http_method             = aws_api_gateway_method.webhook_mercadopago_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "${var.payments_service_url}/webhook/mercadopago"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

# Products Resource
resource "aws_api_gateway_resource" "products" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "products"
}

# Products Category Resource
resource "aws_api_gateway_resource" "products_category" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.products.id
  path_part   = "category"
}

# GET /products/category
resource "aws_api_gateway_method" "products_category_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products_category.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "products_category_get_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products_category.id
  http_method             = aws_api_gateway_method.products_category_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "${var.products_service_url}/products/category"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

# Products ID Resource
resource "aws_api_gateway_resource" "products_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.products.id
  path_part   = "{id}"
}

# GET /products/{id}
resource "aws_api_gateway_method" "products_id_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products_id.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "products_id_get_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products_id.id
  http_method             = aws_api_gateway_method.products_id_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "${var.products_service_url}/products/{id}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.header.Authorization" = false,
    "method.request.path.proxy"           = true
  }
}

resource "aws_api_gateway_integration" "proxy_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${var.eks_service_url}/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"
  request_parameters = {
    "integration.request.path.proxy"           = "method.request.path.proxy",
    "integration.request.header.Authorization" = "method.request.header.Authorization"
  }
}

resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    aws_api_gateway_integration.auth_lambda,
    aws_api_gateway_integration.orders_eks,
    aws_api_gateway_integration.orders_get_eks,
    aws_api_gateway_integration.orders_id_get_eks,
    aws_api_gateway_integration.payments_checkout_post_eks,
    aws_api_gateway_integration.payments_status_orderid_get_eks,
    aws_api_gateway_integration.webhook_mercadopago_post_eks,
    aws_api_gateway_integration.products_category_get_eks,
    aws_api_gateway_integration.products_id_get_eks,
    aws_api_gateway_integration.proxy_eks
  ]
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.auth.id,
      aws_api_gateway_method.auth_post.id,
      aws_api_gateway_integration.auth_lambda.id,
      aws_api_gateway_resource.orders.id,
      aws_api_gateway_method.orders_post.id,
      aws_api_gateway_integration.orders_eks.id,
      aws_api_gateway_resource.products.id,
      aws_api_gateway_method.products_get.id,
      aws_api_gateway_method.products_post.id,
      aws_api_gateway_integration.products_get_eks.id,
      aws_api_gateway_integration.products_post_eks.id,
      aws_api_gateway_resource.products_id.id,
      aws_api_gateway_method.products_id_get.id,
      aws_api_gateway_method.products_id_put.id,
      aws_api_gateway_method.products_id_delete.id,
      aws_api_gateway_integration.products_id_get_eks.id,
      aws_api_gateway_integration.products_id_put_eks.id,
      aws_api_gateway_integration.products_id_delete_eks.id,
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy_any.id,
      aws_api_gateway_integration.proxy_eks.id,
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
