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

variable "spiffe_trust_domain" {
  type    = string
  default = "example"
}

variable "pki_roles" {
  description = "PKI roles to create in Vault for AWS Roles Anywhere certificate issuance."

  type = map(object({
    team         = string
    environment  = string
    organization = optional(list(string), ["example"])
    ttl          = optional(string, "1200")
    max_ttl      = optional(string, "1200")
  }))
}
