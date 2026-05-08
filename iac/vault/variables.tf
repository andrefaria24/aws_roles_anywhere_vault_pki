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

variable "team1_vm_bootstrap_common_name" {
  type        = string
  description = "Common name to issue and trust for the demo team1-vm bootstrap client certificate."
  default     = "team1-vm"
}

variable "team1_vm_bootstrap_certificate_ttl" {
  type        = string
  description = "TTL used for the demo team1-vm bootstrap client certificate issued from the cert-auth intermediate."
  default     = "720h"
}
