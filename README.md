# Infraestrutura Terraform para API Gateway + Lambda + EKS

Este repositório contém a infraestrutura como código para criar uma **API Gateway** na AWS com rotas de autenticação e proxy para microsserviços no EKS, utilizando **Lambda Authorizer** para autenticação. A infraestrutura é gerenciada com **Terraform** e o deploy é feito via **GitHub Actions**.

---

## Estrutura do Repositório

```
fastfood-infra-gtw/
├── main.tf                  # Recursos principais do Terraform (API Gateway, integrações)
├── variables.tf             # Variáveis de configuração
├── backend.tf              # Configuração do backend S3
├── versions.tf             # Versões do Terraform e providers
├── .github/workflows/
│   ├── terraform-deploy.yaml    # Pipeline de deploy (push na main)
│   └── terraform-validate.yaml  # Pipeline de validação (PRs)
└── .gitignore
```

---

## Arquitetura de Microsserviços

A API Gateway roteia as requisições para 4 microsserviços diferentes no EKS através de proxies dedicados:

### **Rotas Configuradas:**

#### **🔐 Autenticação (Lambda)**
- `POST /auth` → Lambda de autenticação (gera Bearer token)

#### **📦 Products System**
- `ANY /fastfood-products-system/api/{proxy+}` → Microsserviço de Produtos
  - Exemplo: `/fastfood-products-system/api/products`
  - Exemplo: `/fastfood-products-system/api/products/{id}`
  - Exemplo: `/fastfood-products-system/api/products/category`

#### **🛒 Orders System**
- `POST /fastfood-orders-system/api/orders` → Criar pedido **🔒 (Protegida com Lambda Authorizer)**
  - Request template transforma payload com dados do cliente autenticado
  - Injeta `clientId` e `cpf` do contexto do authorizer
- `ANY /fastfood-orders-system/api/{proxy+}` → Demais rotas do microsserviço de Pedidos
  - Exemplo: `/fastfood-orders-system/api/orders` (GET - listar)
  - Exemplo: `/fastfood-orders-system/api/orders/{id}` (GET - consultar)

#### **💳 Payment System**
- `ANY /fastfood-payment-system/api/{proxy+}` → Microsserviço de Pagamentos
  - Exemplo: `/fastfood-payment-system/api/payments/checkout`
  - Exemplo: `/fastfood-payment-system/api/payments/status/{orderId}`
  - Exemplo: `/fastfood-payment-system/api/webhook/mercadopago`

#### **👨‍🍳 Kitchen System**
- `ANY /fastfood-kitchen-system/api/{proxy+}` → Microsserviço de Cozinha
  - Exemplo: `/fastfood-kitchen-system/api/orders/queue`
  - Exemplo: `/fastfood-kitchen-system/api/orders/{id}/status`

---

## Recursos Criados

- **API Gateway REST API** com rotas proxy para cada microsserviço
- **Lambda Authorizer** configurado para validação de token JWT/Bearer
- **Rota POST /orders protegida** com request template VTL para injeção de dados do cliente
- **Integração HTTP_PROXY** com microsserviços no EKS via ALB/NLB
- **Deploy automatizado** via GitHub Actions com validação em PRs
- **Stage de Produção** configurado

---

## Secrets Necessários no GitHub

Configure os seguintes secrets no repositório GitHub:

### **AWS Credentials**
- `AWS_REGION` - Região AWS (ex: `us-east-1`)
- `AWS_ACCESS_KEY_ID` - Access Key ID da AWS
- `AWS_SECRET_ACCESS_KEY` - Secret Access Key da AWS
- `AWS_SESSION_TOKEN` - Session Token (se usar credenciais temporárias)

### **Lambda Functions**
- `AUTH_LAMBDA_INVOKE_ARN` - ARN de invocação da Lambda de autenticação
- `AUTHORIZER_LAMBDA_INVOKE_ARN` - URI da Lambda Authorizer

### **Microsserviços EKS**
- `PRODUCTS_SERVICE_URL` - URL do ALB/NLB do serviço de produtos (ex: `http://products-alb-123.us-east-1.elb.amazonaws.com`)
- `ORDERS_SERVICE_URL` - URL do ALB/NLB do serviço de pedidos
- `PAYMENTS_SERVICE_URL` - URL do ALB/NLB do serviço de pagamentos
- `KITCHEN_SERVICE_URL` - URL do ALB/NLB do serviço de cozinha

---

## Como Usar

### **1. Desenvolvimento Local**

```bash
# Inicializar Terraform
terraform init

# Validar configuração
terraform validate

# Planejar mudanças
terraform plan \
  -var="auth_lambda_invoke_arn=arn:aws:..." \
  -var="authorizer_lambda_invoke_arn=arn:aws:..." \
  -var="products_service_url=http://..." \
  -var="orders_service_url=http://..." \
  -var="payments_service_url=http://..." \
  -var="kitchen_service_url=http://..."

# Aplicar mudanças
terraform apply
```

### **2. Deploy via GitHub Actions**

- **Push na `main`**: Executa `terraform-deploy.yaml` (valida + aplica)
- **Pull Request**: Executa `terraform-validate.yaml` (valida + plan)

---

## Comunicação entre Microsserviços

### **Externa (Pública via API Gateway)**
```
Cliente → API Gateway → ALB/NLB → Microsserviço
```

### **Interna (Serviço-a-Serviço)**
```
Microsserviço A → Kubernetes Service → Microsserviço B
```

Rotas internas NÃO expostas no API Gateway devem ser chamadas diretamente via DNS interno do Kubernetes:
```
http://products-service.default.svc.cluster.local:8080
http://orders-service.default.svc.cluster.local:8080
```

---

## Estrutura de Rotas

### **Agora (proxy por microsserviço):**
```
/fastfood-products-system/api/products/category
/fastfood-products-system/api/products/{id}
/fastfood-orders-system/api/orders
/fastfood-orders-system/api/orders/{id}
/fastfood-payment-system/api/payments/checkout
```

**Vantagens:**
- ✅ Flexibilidade para adicionar novas rotas sem alterar Terraform
- ✅ Roteamento claro por microsserviço
- ✅ Namespace isolado por sistema
- ✅ Rotas específicas podem ter autenticação customizada

---

## Rotas Autenticadas

### **POST /fastfood-orders-system/api/orders** 🔒

Esta rota é **protegida** com Lambda Authorizer e possui um **request template** que:

1. **Valida o token Bearer** antes de processar a requisição
2. **Transforma o payload** com base no contexto do authorizer:

**Cenário 1 - Cliente Autenticado:**
```json
// Request do cliente
{
  "items": [{"id": 1, "quantity": 2}]
}

// Transformado para o EKS
{
  "client": {
    "id": "abc123",      // Do authorizer context
    "cpf": "12345678900" // Do authorizer context
  },
  "items": [{"id": 1, "quantity": 2}]
}
```

**Cenário 2 - Cliente já no payload:**
```json
// Request do cliente
{
  "client": {"id": "xyz", "cpf": "111"},
  "items": [{"id": 1, "quantity": 2}]
}

// Enviado como está (sem modificação)
```

**Cenário 3 - Cliente Anônimo:**
```json
// Request sem cliente autenticado
{
  "items": [{"id": 1, "quantity": 2}]
}

// Enviado apenas com items
{
  "items": [{"id": 1, "quantity": 2}]
}
```
- ✅ Suporte a qualquer método HTTP (GET, POST, PUT, DELETE, etc)

---

## Troubleshooting

### **Erro: "No value for required variable"**
Certifique-se de que todos os secrets estão configurados no GitHub.

### **Erro 403/502 no API Gateway**
Verifique se as URLs dos microsserviços estão corretas e acessíveis.

### **Deploy não funciona**
Verifique os logs no GitHub Actions e valide as permissões AWS.

---

## Licença

MIT
