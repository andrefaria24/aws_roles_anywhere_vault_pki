resource "vault_mount" "pki" {
  path                  = "pki-aws-2"
  type                  = "pki"
  max_lease_ttl_seconds = 157680000 # 5 years
}

resource "vault_mount" "pki_intermediate" {
  path                  = "pki-aws-2-int"
  type                  = "pki"
  max_lease_ttl_seconds = 31536000 # 365 days
}

resource "vault_pki_secret_backend_root_cert" "root" {
  depends_on  = [vault_mount.pki]
  backend     = vault_mount.pki.path
  type        = "internal"
  common_name = "example.com"
  ttl         = "1825d" # 5 years
}

resource "vault_pki_secret_backend_intermediate_cert_request" "roles_anywhere" {
  depends_on  = [vault_mount.pki_intermediate]
  backend     = vault_mount.pki_intermediate.path
  type        = "internal"
  common_name = "example.com Intermediate CA"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "roles_anywhere" {
  depends_on  = [vault_pki_secret_backend_intermediate_cert_request.roles_anywhere]
  backend     = vault_mount.pki.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.roles_anywhere.csr
  common_name = "example.com Intermediate CA"
  ttl         = "365d" # 1 year
}

resource "vault_pki_secret_backend_intermediate_set_signed" "roles_anywhere" {
  depends_on  = [vault_pki_secret_backend_root_sign_intermediate.roles_anywhere]
  backend     = vault_mount.pki_intermediate.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.roles_anywhere.certificate
}

# write the intermediate CA to a local file to provide to the AWS team
resource "local_file" "vault_intermediate_cert" {
  content  = vault_pki_secret_backend_root_sign_intermediate.roles_anywhere.certificate
  filename = "vault_intermediate_cert.pem"
}

# create PKI roles
resource "vault_pki_secret_backend_role" "team1_dev" {
  backend = vault_mount.pki_intermediate.path
  name    = "team1-dev"

  require_cn       = false
  allow_any_name   = false
  allowed_uri_sans = ["spiffe://example/team1/dev/*"]

  ttl     = "1200" # 20 minutes
  max_ttl = "1200" # 20 minutes
}

resource "vault_pki_secret_backend_role" "team1_prod" {
  backend = vault_mount.pki_intermediate.path
  name    = "team1-prod"

  require_cn       = false
  allow_any_name   = false
  allowed_uri_sans = ["spiffe://example/team1/prod/*"]

  ttl     = "1200" # 20 minutes
  max_ttl = "1200" # 20 minutes
}

resource "vault_pki_secret_backend_role" "team2_dev" {
  backend = vault_mount.pki_intermediate.path
  name    = "team2-dev"

  require_cn       = false
  allow_any_name   = false
  allowed_uri_sans = ["spiffe://example/team2/dev/*"]

  ttl     = "1200" # 20 minutes
  max_ttl = "1200" # 20 minutes
}

# create policies for issuing certs
resource "vault_policy" "team1_dev" {
  name = "team1-dev-ra-policy"

  policy = <<EOT
path "pki-aws-2-int/issue/team1-dev" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "team1_prod" {
  name = "team1-prod-ra-policy"

  policy = <<EOT
path "pki-aws-2-int/issue/team1-prod" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "team2_dev" {
  name = "team2-dev-ra-policy"

  policy = <<EOT
path "pki-aws-2-int/issue/team2-dev" {
  capabilities = ["update"]
}
EOT
}

# configure AppRole auth method and roles for each team to retrieve certs
resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_approle_auth_backend_role" "team1_dev" {
  backend        = vault_auth_backend.approle.path
  role_name      = "team1-dev"
  secret_id_ttl  = 900
  token_ttl      = 900
  token_max_ttl  = 900
  token_policies = ["team1-dev-ra-policy"]
}

resource "vault_approle_auth_backend_role" "team1_prod" {
  backend        = vault_auth_backend.approle.path
  role_name      = "team1-prod"
  secret_id_ttl  = 900
  token_ttl      = 900
  token_max_ttl  = 900
  token_policies = ["team1-prod-ra-policy"]
}

resource "vault_approle_auth_backend_role" "team2_dev" {
  backend        = vault_auth_backend.approle.path
  role_name      = "team2-dev"
  secret_id_ttl  = 900
  token_ttl      = 900
  token_max_ttl  = 900
  token_policies = ["team2-dev-ra-policy"]
}

# policies for generating AppRole secret_ids
resource "vault_policy" "team1_dev_approle_secret_id" {
  name = "team1-dev-approle-secretid"

  policy = <<EOT
path "auth/approle/role/team1-dev/secret-id" {
  capabilities = ["create", "update"]
}
EOT
}

resource "vault_policy" "team1_prod_approle_secret_id" {
  name = "team1-prod-approle-secretid"

  policy = <<EOT
path "auth/approle/role/team1-prod/secret-id" {
  capabilities = ["create", "update"]
}
EOT
}

resource "vault_policy" "team2_dev_approle_secret_id" {
  name = "team2-dev-approle-secretid"

  policy = <<EOT
path "auth/approle/role/team2-dev/secret-id" {
  capabilities = ["create", "update"]
}
EOT
}
