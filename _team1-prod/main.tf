resource "aws_iam_role" "spoke" {
  name = var.spoke_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TrustHubRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.hub_account_id}:role/${var.hub_role_name}"
        }
        Action = [
          "sts:AssumeRole",
          "sts:SetSourceIdentity",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "spoke_readonly" {
  count = var.permissions_mode == "readonly" ? 1 : 0
  name  = "${var.spoke_role_name}-readonly"
  role  = aws_iam_role.spoke.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyDemo"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "ec2:DescribeInstances",
          "ec2:DescribeAccountAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "spoke_admin" {
  count      = var.permissions_mode == "admin" ? 1 : 0
  role       = aws_iam_role.spoke.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_s3_bucket" "team_bucket" {
  bucket_prefix = "team1-prod-"
}
