output "roles_anywhere_issuer_certificate" {
  value     = vault_pki_secret_backend_intermediate_set_signed.roles_anywhere.certificate
  sensitive = true
}