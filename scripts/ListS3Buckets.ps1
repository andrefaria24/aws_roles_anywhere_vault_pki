param(
  [Parameter(Mandatory = $true)]
  [string]$TrustAnchorArn,

  [Parameter(Mandatory = $true)]
  [string]$ProfileArn,

  [Parameter(Mandatory = $true)]
  [string]$RoleArn,

  [string]$CertificatePath = ".\\certs\\cert.pem",

  [string]$PrivateKeyPath = ".\\certs\\key.pem",

  [string]$Region = "us-east-2",

  [string]$Endpoint = "https://rolesanywhere.us-east-2.amazonaws.com"
)

$ErrorActionPreference = "Stop"

$creds = aws_signing_helper credential-process `
  --certificate $CertificatePath `
  --private-key $PrivateKeyPath `
  --trust-anchor-arn $TrustAnchorArn `
  --profile-arn $ProfileArn `
  --role-arn $RoleArn `
  --region $Region `
  --endpoint $Endpoint | ConvertFrom-Json

$env:AWS_ACCESS_KEY_ID     = $creds.AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $creds.SecretAccessKey
$env:AWS_SESSION_TOKEN     = $creds.SessionToken

aws sts get-caller-identity
aws s3 ls
