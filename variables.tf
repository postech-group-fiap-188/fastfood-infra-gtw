variable "region" {
  type    = string
  default = "sa-east-1"
}

variable "stage_name" {
  type    = string
  default = "dev"
}

variable "auth_lambda_invoke_arn" {
  description = "Invoke ARN da Lambda de autenticação"
  type        = string
}

variable "authorizer_lambda_invoke_arn" {
  description = "Authorizer Lambda invoke URI (formato apigateway)"
  type        = string
}

variable "eks_service_url" {
  description = "Endpoint do serviço no EKS (ALB/NLB URL)"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile para uso local. No CI/CD usar credenciais via OIDC/secrets."
  type        = string
  default     = ""
}