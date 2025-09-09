region       = "sa-east-1"
stage_name   = "prod"
aws_profile  = "profile-prod"

auth_lambda_invoke_arn       = "arn:aws:lambda:sa-east-1:222222222222:function:auth-lambda-prod"
authorizer_lambda_invoke_arn = "arn:aws:apigateway:sa-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:sa-east-1:222222222222:function:authorizer-lambda-prod/invocations"
eks_service_url              = "http://meu-loadbalancer.eks.amazonaws.com"
