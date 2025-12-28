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

- **API Gateway** com as seguintes rotas mapeadas:
  
  **Autenticação:**
  - `POST /auth` → Lambda de autenticação (Bearer token)
  
  **Orders (Pedidos):**
  - `POST /orders` → Criar pedido (protegido por Lambda Authorizer)
  - `GET /orders` → Listar pedidos
  - `GET /orders/{id}` → Buscar pedido por ID
  
  **Payments (Pagamentos):**
  - `POST /payments/checkout` → Processar checkout
  - `GET /payments/status/{orderId}` → Consultar status de pagamento
  
  **Webhooks:**
  - `POST /webhook/mercadopago` → Webhook do Mercado Pago
  
  **Products (Produtos):**
  - `GET /products/category` → Listar produtos por categoria
  - `GET /products/{id}` → Buscar produto por ID
  
  **Proxy Catch-All:**
  - `ANY /{proxy+}` → Encaminha todas as rotas não mapeadas para o EKS (inclui Authorization header)

- **Lambda Authorizer** configurado para validação de token em rotas protegidas
- **Integração com microsserviços no EKS** via HTTP/NLB ou ALB
- **Deploy automatizado** via GitHub Actions

---
