terraform {
  required_version = "~> 1.14.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.7.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.31.0"
    }
  }
}
