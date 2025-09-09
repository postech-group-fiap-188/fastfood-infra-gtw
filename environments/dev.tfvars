region       = "sa-east-1"
stage_name   = "dev"
aws_profile  = "profile-dev"

auth_lambda_invoke_arn       = "arn:aws:lambda:sa-east-1:111111111111:function:auth-lambda-dev"
authorizer_lambda_invoke_arn = "arn:aws:apigateway:sa-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:sa-east-1:111111111111:function:authorizer-lambda-dev/invocations"
eks_service_url              = "http://meu-loadbalancer-dev.eks.amazonaws.com"
