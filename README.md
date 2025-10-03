# Infraestrutura Terraform para API Gateway + Lambda + EKS

Este repositório contém a infraestrutura como código para criar uma **API Gateway** na AWS com rotas de autenticação e proxy para um serviço no EKS, utilizando **Lambda Authorizer** para autenticação. A infraestrutura é gerenciada com **Terraform** e o deploy é feito via **GitHub Actions**.

---

## Estrutura do Repositório

```json
infra-api-gateway/
├─ main.tf # Recursos principais do Terraform (API Gateway,integrações)
├── variables.tf # Variáveis de configuração
├── outputs.tf # Outputs do Terraform
├── environments/
│ ├── dev.tfvars # Variáveis de ambiente Dev
│ └── prod.tfvars # Variáveis de ambiente Prod
├── .github/workflows/
│ └── terraform-validate.yml # Pipeline GitHub Actions
└── .gitignore # Ignora arquivos sensíveis como .env, tfstate
```

---

## Recursos Criados

- **API Gateway** com três rotas:
  - `/auth` → rota de autenticação via Lambda (Bearer token)
  - `/order` → rota protegida via Lambda Authorizer
  - `/proxy` → rota proxy opcional, passa header Authorization
- **Lambda Authorizer** configurado para `/order`
- **Integração com serviço EKS** via HTTP/NLB ou ALB
- **Deploy automatizado** via GitHub Actions

---
