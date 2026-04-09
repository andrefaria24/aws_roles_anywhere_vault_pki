output "role_names" {
  value = {
    for key, role in aws_iam_role.iam_roles_anywhere_assume_role : key => role.name
  }
}

output "role_arns" {
  value = {
    for key, role in aws_iam_role.iam_roles_anywhere_assume_role : key => role.arn
  }
}

output "role_arns_by_team" {
  value = {
    for team in sort(keys(var.team_apps)) : team => [
      for key in sort(keys(local.team_app_pairs)) :
      aws_iam_role.iam_roles_anywhere_assume_role[key].arn
      if local.team_app_pairs[key].team == team
    ]
  }
}
