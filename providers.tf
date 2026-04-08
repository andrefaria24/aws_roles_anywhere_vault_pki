provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = [var.aws_credentials_file_location]
  profile                  = var.aws_profile
}
