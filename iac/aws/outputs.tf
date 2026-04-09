output "role_names" {
  value = module.iam_roles.role_names
}

output "role_arns" {
  value = module.iam_roles.role_arns
}

output "role_arns_by_team" {
  value = module.iam_roles.role_arns_by_team
}

output "profile_names_by_team" {
  value = module.profiles.profile_names_by_team
}

output "profile_arns_by_team" {
  value = module.profiles.profile_arns_by_team
}

output "profile_ids_by_team" {
  value = module.profiles.profile_ids_by_team
}
