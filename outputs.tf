# output "pki-path" {
#   value = vault_mount.pki.path
# }
output "trust-anchor-arn" {
  value = aws_rolesanywhere_trust_anchor.test.arn
}

output "team1-profile-arn" {
  value = aws_rolesanywhere_profile.ra_profile_team1.arn
}

output "team2-profile-arn" {
  value = aws_rolesanywhere_profile.ra_profile_team2.arn
}

output "team1-dev-hub-role-arn" {
  value = aws_iam_role.ra_hub_team1_dev.arn
}

output "team1-prod-hub-role-arn" {
  value = aws_iam_role.ra_hub_team1_prod.arn
}

output "team2-dev-hub-role-arn" {
  value = aws_iam_role.ra_hub_team2_dev.arn
}

output "team1-dev-approle-role-id" {
  value = vault_approle_auth_backend_role.team1_dev.role_id
}

output "team1-prod-approle-role-id" {
  value = vault_approle_auth_backend_role.team1_prod.role_id
}

output "team2-dev-approle-role-id" {
  value = vault_approle_auth_backend_role.team2_dev.role_id
}
