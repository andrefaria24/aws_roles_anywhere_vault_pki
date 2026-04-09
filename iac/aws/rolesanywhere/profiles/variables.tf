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

variable "role_arns_by_team" {
  type = map(list(string))
}
