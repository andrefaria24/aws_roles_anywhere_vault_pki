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

resource "vault_mount" "pki_cert_auth_intermediate" {
  path                  = "pki-auth-cert-int"
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

resource "vault_pki_secret_backend_intermediate_cert_request" "cert_auth" {
  depends_on  = [vault_mount.pki_cert_auth_intermediate]
  backend     = vault_mount.pki_cert_auth_intermediate.path
  type        = "internal"
  common_name = "${var.domain_name} Cert Auth Intermediate CA"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "cert_auth" {
  depends_on  = [vault_pki_secret_backend_intermediate_cert_request.cert_auth]
  backend     = vault_mount.pki.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.cert_auth.csr
  common_name = "${var.domain_name} Cert Auth Intermediate CA"
  ttl         = "365d" # 1 year
}

resource "vault_pki_secret_backend_intermediate_set_signed" "cert_auth" {
  depends_on  = [vault_pki_secret_backend_root_sign_intermediate.cert_auth]
  backend     = vault_mount.pki_cert_auth_intermediate.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.cert_auth.certificate
}

resource "vault_pki_secret_backend_role" "team1_vm_bootstrap" {
  backend            = vault_mount.pki_cert_auth_intermediate.path
  name               = "team1-vm"
  require_cn         = true
  allow_any_name     = false
  allowed_domains    = [var.team1_vm_bootstrap_common_name]
  allow_bare_domains = true
  allow_subdomains   = false
  allow_glob_domains = false

  server_flag = false
  client_flag = true

  ttl     = var.team1_vm_bootstrap_certificate_ttl
  max_ttl = var.team1_vm_bootstrap_certificate_ttl
}

resource "vault_pki_secret_backend_cert" "team1_vm_bootstrap" {
  backend     = vault_mount.pki_cert_auth_intermediate.path
  name        = vault_pki_secret_backend_role.team1_vm_bootstrap.name
  common_name = var.team1_vm_bootstrap_common_name
  ttl         = var.team1_vm_bootstrap_certificate_ttl
}

resource "vault_auth_backend" "cert" {
  type = "cert"
  path = "cert"
}

resource "vault_policy" "team1_vm_issue_certs" {
  name = "team1-vm-issue-team1-certs"

  policy = <<EOT
path "pki-aws-int/issue/team1" {
  capabilities = ["update"]
}

path "pki-aws-int/issue/team1/*" {
  capabilities = ["update"]
}
EOT
}

resource "vault_cert_auth_backend_role" "team1_vm" {
  backend                 = vault_auth_backend.cert.path
  name                    = "team1-vm"
  certificate             = trimspace(vault_pki_secret_backend_root_sign_intermediate.cert_auth.certificate)
  allowed_common_names    = [var.team1_vm_bootstrap_common_name]
  token_policies          = [vault_policy.team1_vm_issue_certs.name]
  token_no_default_policy = true
  token_ttl               = 1800
  token_max_ttl           = 1800
}

# Write the intermediate CA to a local file to provide to the AWS team
resource "local_file" "vault_intermediate_cert" {
  content  = vault_pki_secret_backend_root_sign_intermediate.roles_anywhere.certificate
  filename = ".\\certs\\vault_intermediate_cert.pem"
}

resource "local_file" "vault_cert_auth_intermediate_cert" {
  content  = vault_pki_secret_backend_root_sign_intermediate.cert_auth.certificate
  filename = ".\\certs\\vault_cert_auth_intermediate_cert.pem"
}

resource "local_file" "team1_vm_bootstrap_client_cert" {
  content  = "${trimspace(vault_pki_secret_backend_cert.team1_vm_bootstrap.certificate)}\n${trimspace(vault_pki_secret_backend_cert.team1_vm_bootstrap.issuing_ca)}\n"
  filename = ".\\certs\\team1_vm_bootstrap_client_cert.pem"
}

resource "local_file" "team1_vm_bootstrap_client_ca" {
  content  = vault_pki_secret_backend_cert.team1_vm_bootstrap.issuing_ca
  filename = ".\\certs\\team1_vm_bootstrap_client_ca.pem"
}

resource "local_sensitive_file" "team1_vm_bootstrap_client_key" {
  content  = vault_pki_secret_backend_cert.team1_vm_bootstrap.private_key
  filename = ".\\certs\\team1_vm_bootstrap_client_key.pem"
}
