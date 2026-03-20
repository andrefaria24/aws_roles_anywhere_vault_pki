variable "hub_account_id" {
  type = string
}

variable "hub_role_name" {
  type = string
  # examples: "ra-hub-team1-dev", "ra-hub-team1-prod", or "ra-hub-team2-dev"
}

variable "spoke_role_name" {
  type = string
  # examples: "ra-spoke-team1-dev"
}

# optional: if you want distinct permissions per env/team
variable "permissions_mode" {
  type    = string
  default = "readonly" # readonly | admin
}
