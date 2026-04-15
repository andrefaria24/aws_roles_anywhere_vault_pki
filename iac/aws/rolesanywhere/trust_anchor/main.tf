data "tls_certificate" "cert" {
  content = file("${path.module}/certs/vault_intermediate_cert.pem")
}

resource "aws_rolesanywhere_trust_anchor" "hcp_vault" {
  name    = "hcp-vault-rolesanywhere-trust-anchor"
  enabled = true
  source {
    source_data {
      x509_certificate_data = "${trimspace(file("${path.module}/certs/vault_intermediate_cert.pem"))}\n"
    }
    source_type = "CERTIFICATE_BUNDLE"
  }
}
