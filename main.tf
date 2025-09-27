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
  name            = "bearer-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "TOKEN"
  identity_source = "method.request.header.Authorization"
  authorizer_uri  = var.authorizer_lambda_invoke_arn
}

resource "aws_api_gateway_resource" "order" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "order"
}

resource "aws_api_gateway_method" "order_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.order.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.token.id

  request_parameters = {
    "method.request.header.Authorization" = false
  }
}

resource "aws_api_gateway_integration" "order_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.order.id
  http_method             = aws_api_gateway_method.order_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP"
  uri                     = var.eks_service_url

  request_templates = {
    "application/json" = <<EOF
#set($inputRoot = $input.path('$'))
{
  "cpf": "$context.authorizer.cpf",
  "clientId": "$context.authorizer.clientId",
#foreach($key in $inputRoot.keySet())
  "$key": $input.json('$.$key')#if($foreach.hasNext),#end
#end
}
EOF
  }

  passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "proxy"
}

resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.header.Authorization" = false
  }
}

resource "aws_api_gateway_integration" "proxy_eks" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = var.eks_service_url
  passthrough_behavior    = "WHEN_NO_MATCH"
  request_parameters = {
    "integration.request.header.Authorization" = "method.request.header.Authorization"
  }
}

resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    aws_api_gateway_integration.auth_lambda,
    aws_api_gateway_integration.order_eks,
    aws_api_gateway_integration.proxy_eks
  ]
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = var.stage_name
}
