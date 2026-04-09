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
