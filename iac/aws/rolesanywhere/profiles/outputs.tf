output "profile_names_by_team" {
  value = {
    for team, profile in aws_rolesanywhere_profile.team : team => profile.name
  }
}

output "profile_arns_by_team" {
  value = {
    for team, profile in aws_rolesanywhere_profile.team : team => profile.arn
  }
}

output "profile_ids_by_team" {
  value = {
    for team, profile in aws_rolesanywhere_profile.team : team => profile.id
  }
}
