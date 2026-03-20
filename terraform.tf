terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.7.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.31.0"
    }
  }
}

provider "vault" {
  address = var.address
  token   = var.token
}

provider "aws" {
  # Configuration options
}
