provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = [var.aws_credentials_file_location]
  profile                  = var.aws_profile
}