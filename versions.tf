
terraform {
  required_version = "~> 1.1.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "= 2.21.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "= 3.73.0"
    }
    ansible = {
      source  = "nbering/ansible"
      version = "= 1.0.4"
    }
  }
}
