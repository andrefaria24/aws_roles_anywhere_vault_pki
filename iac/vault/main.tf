resource "vault_mount" "pki" {
  path                  = "pki-aws-root"
  type                  = "pki"
  max_lease_ttl_seconds = 157680000 # 5 years
}

resource "vault_mount" "pki_intermediate" {
  path                  = "pki-aws-int"
  type                  = "pki"
  max_lease_ttl_seconds = 31536000 # 365 days
}

resource "vault_pki_secret_backend_root_cert" "root" {
  depends_on  = [vault_mount.pki]
  backend     = vault_mount.pki.path
  type        = "internal"
  common_name = var.domain_name
  ttl         = "1825d" # 5 years
}

resource "vault_pki_secret_backend_intermediate_cert_request" "roles_anywhere" {
  depends_on  = [vault_mount.pki_intermediate]
  backend     = vault_mount.pki_intermediate.path
  type        = "internal"
  common_name = "${var.domain_name} Intermediate CA"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "roles_anywhere" {
  depends_on  = [vault_pki_secret_backend_intermediate_cert_request.roles_anywhere]
  backend     = vault_mount.pki.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.roles_anywhere.csr
  common_name = "${var.domain_name} Intermediate CA"
  ttl         = "365d" # 1 year
}

resource "vault_pki_secret_backend_intermediate_set_signed" "roles_anywhere" {
  depends_on  = [vault_pki_secret_backend_root_sign_intermediate.roles_anywhere]
  backend     = vault_mount.pki_intermediate.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.roles_anywhere.certificate
}

# Write the intermediate CA to a local file to provide to the AWS team
resource "local_file" "vault_intermediate_cert" {
  content  = vault_pki_secret_backend_root_sign_intermediate.roles_anywhere.certificate
  filename = ".\\certs\\vault_intermediate_cert.pem"
}
