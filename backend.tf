terraform {
  backend "s3" {
    bucket       = "gtw-terraform"
    key          = "terraform/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}