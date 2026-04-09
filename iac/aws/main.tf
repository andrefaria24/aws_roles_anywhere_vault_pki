module "trust_anchor" {
  source = "./rolesanywhere/trust_anchor"

  aws_region                    = var.aws_region
  aws_profile                   = var.aws_profile
  aws_credentials_file_location = var.aws_credentials_file_location
}


module "iam_roles" {
  source = "./iam_roles"

  aws_region                    = var.aws_region
  aws_profile                   = var.aws_profile
  aws_credentials_file_location = var.aws_credentials_file_location
  team_apps                     = var.team_apps
}

module "profiles" {
  source = "./rolesanywhere/profiles"

  aws_region                    = var.aws_region
  aws_profile                   = var.aws_profile
  aws_credentials_file_location = var.aws_credentials_file_location
  role_arns_by_team             = module.iam_roles.role_arns_by_team
}
