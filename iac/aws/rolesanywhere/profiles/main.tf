resource "aws_rolesanywhere_profile" "team" {
  for_each = var.role_arns_by_team

  name             = "hcp-vault-${each.key}"
  enabled          = true
  duration_seconds = 3600

  role_arns = each.value
}
