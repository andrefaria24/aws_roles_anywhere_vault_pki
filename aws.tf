data "tls_certificate" "cert" {
  content = vault_pki_secret_backend_intermediate_set_signed.roles_anywhere.certificate
}

resource "aws_rolesanywhere_trust_anchor" "test" {
  name    = "terraform-ta"
  enabled = true
  source {
    source_data {
      x509_certificate_data = "${trimspace(vault_pki_secret_backend_intermediate_set_signed.roles_anywhere.certificate)}\n"
    }
    source_type = "CERTIFICATE_BUNDLE"
  }
  tags = {
    serial_number       = vault_pki_secret_backend_root_sign_intermediate.roles_anywhere.serial_number
    cert_expiration_iso = data.tls_certificate.cert.certificates[0].not_after
  }

  # Wait for the signed intermediate certificate to be ready
  depends_on = [vault_pki_secret_backend_intermediate_set_signed.roles_anywhere]
}

resource "aws_rolesanywhere_profile" "ra_profile_team1" {
  name             = "ra-profile-team1"
  enabled          = true
  duration_seconds = 3600

  role_arns = [
    aws_iam_role.ra_hub_team1_dev.arn,
    aws_iam_role.ra_hub_team1_prod.arn
  ]
}

resource "aws_rolesanywhere_profile" "ra_profile_team2" {
  name             = "ra-profile-team2"
  enabled          = true
  duration_seconds = 3600

  role_arns = [
    aws_iam_role.ra_hub_team2_dev.arn
  ]
}

####
# Team 1 Dev Spoke Role
resource "aws_iam_role" "ra_hub_team1_dev" {
  name = "ra-hub-team1-dev"

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
          "aws:PrincipalTag/x509SAN/URI" = "spiffe://example/team1/dev/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ra_hub_team1_dev_policy" {
  role = aws_iam_role.ra_hub_team1_dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:SetSourceIdentity",
          "sts:TagSession"
        ]
        Resource = [
          "arn:aws:iam::${var.team1_dev_account_id}:role/${var.team1_dev_spoke_role_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      }
    ]
  })
}

# Team 1 Prod Spoke Role
resource "aws_iam_role" "ra_hub_team1_prod" {
  name = "ra-hub-team1-prod"

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
          "aws:PrincipalTag/x509SAN/URI" = "spiffe://example/team1/prod/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ra_hub_team1_prod_policy" {
  role = aws_iam_role.ra_hub_team1_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sts:AssumeRole",
        "sts:SetSourceIdentity",
        "sts:TagSession"
      ]
      Resource = [
        "arn:aws:iam::${var.team1_prod_account_id}:role/${var.team1_prod_spoke_role_name}"
      ]
    }]
  })
}

# Team 2 Dev Spoke Role
resource "aws_iam_role" "ra_hub_team2_dev" {
  name = "ra-hub-team2-dev"

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
          "aws:PrincipalTag/x509SAN/URI" = "spiffe://example/team2/dev/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ra_hub_team2_dev_policy" {
  role = aws_iam_role.ra_hub_team2_dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sts:AssumeRole",
        "sts:SetSourceIdentity",
        "sts:TagSession"
      ]
      Resource = [
        "arn:aws:iam::${var.team2_dev_account_id}:role/${var.team2_dev_spoke_role_name}"
      ]
    }]
  })
}
