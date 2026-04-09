data "tls_certificate" "cert" {
  #content = vault_pki_secret_backend_intermediate_set_signed.roles_anywhere.certificate
  content = file("${path.module}/certs/vault_intermediate_cert.pem")
}

resource "aws_rolesanywhere_trust_anchor" "hcp_vault" {
  name    = "hcp-vault-rolesanywhere-trust-anchor"
  enabled = true
  source {
    source_data {
      #x509_certificate_data = "${trimspace(vault_pki_secret_backend_intermediate_set_signed.roles_anywhere.certificate)}\n"
      x509_certificate_data = "${trimspace(file("${path.module}/certs/vault_intermediate_cert.pem"))}\n"
    }
    source_type = "CERTIFICATE_BUNDLE"
  }
  # tags = {
  #   serial_number       = vault_pki_secret_backend_root_sign_intermediate.roles_anywhere.serial_number
  #   cert_expiration_iso = data.tls_certificate.cert.certificates[0].not_after
  # }

  # Wait for the signed intermediate certificate to be ready
  #depends_on = [vault_pki_secret_backend_intermediate_set_signed.roles_anywhere]
}
