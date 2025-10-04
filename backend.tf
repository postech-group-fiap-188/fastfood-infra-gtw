terraform {
  backend "s3" {
    bucket       = "postech-fiap-188-gtw-terraform"
    key          = "terraform/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}