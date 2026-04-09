variable "vault_address" {
  type = string
}

variable "vault_token" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type    = string
  default = "example.com"
}
