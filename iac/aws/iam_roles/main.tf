locals {
  team_app_pairs = merge([
    for team, apps in var.team_apps : {
      for app in apps : "${team}:${app}" => {
        team = team
        app  = app
      }
    }
  ]...)
}

resource "aws_iam_role" "iam_roles_anywhere_assume_role" {
  for_each = local.team_app_pairs

  name = "HCPVaultAssumeRoleFor${each.value.team}${each.value.app}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "rolesanywhere.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession",
        "sts:SetSourceIdentity"
      ]
      Condition = {
        StringLike = {
          "aws:PrincipalTag/x509SAN/URI" = "spiffe://example/${each.value.team}/${each.value.app}/*"
        }
      }
    }]
  })
}

resource "vault_pki_secret_backend_role" "team_roles" {
  for_each = var.team_apps

  backend = "pki-aws-int" # Hardcoded for now
  name    = lower(each.key)

  require_cn     = false
  allow_any_name = false
  allowed_uri_sans = [
    for app in sort(tolist(each.value)) : "spiffe://example/${each.key}/${app}/*"
  ]

  ttl     = "1800" # 30 minutes
  max_ttl = "1800" # 30 minutes
}

resource "vault_policy" "issue_certs" {
  for_each = var.team_apps

  name = "${lower(each.key)}-iam-roles-anywhere-issue-certs"

  policy = <<EOT
path "pki-aws-int/issue/${lower(each.key)}" {
  capabilities = ["update"]
}

path "pki-aws-int/issue/${lower(each.key)}/*" {
  capabilities = ["update"]
}
EOT
}
