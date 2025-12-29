region = "us-east-1"

stage_name = "prod"

# Lambda ARNs para autenticação
auth_lambda_invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:106185763495:function:fastfood-system-validate-cpf/invocations"

authorizer_lambda_invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:106185763495:function:fastfood-system-token-authorizer-academy/invocations"

# URLs dos microserviços
products_service_url = "http://a52d4ad0d6e5b4d76adec2f2a0928c3e-6fcd1f92fa691616.elb.us-east-1.amazonaws.com"

orders_service_url = "http://a52d4ad0d6e5b4d76adec2f2a0928c3e-6fcd1f92fa691616.elb.us-east-1.amazonaws.com"

payments_service_url = "http://a52d4ad0d6e5b4d76adec2f2a0928c3e-6fcd1f92fa691616.elb.us-east-1.amazonaws.com"

kitchen_service_url = "http://a52d4ad0d6e5b4d76adec2f2a0928c3e-6fcd1f92fa691616.elb.us-east-1.amazonaws.com"
