variable "vault_address" {
  type = string
}

variable "vault_token" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "aws_profile" {
  type = string
}

variable "aws_credentials_file_location" {
  type      = string
  sensitive = true
}

variable "team1_dev_account_id" {
  type = string
}

variable "team1_prod_account_id" {
  type = string
}

variable "team2_dev_account_id" {
  type = string
}

variable "team1_dev_spoke_role_name" {
  type = string
}

variable "team1_prod_spoke_role_name" {
  type = string
}

variable "team2_dev_spoke_role_name" {
  type = string
}
