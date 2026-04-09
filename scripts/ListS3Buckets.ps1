$creds = aws_signing_helper credential-process `
  --certificate .\certs\cert.pem `
  --private-key .\certs\key.pem `
  --trust-anchor-arn arn:aws:rolesanywhere:us-east-2:337501927775:trust-anchor/b6ab79ec-d9e7-4028-9dd1-9fa98f1dbadc `
  --profile-arn arn:aws:rolesanywhere:us-east-2:337501927775:profile/00c55659-c86f-4321-a258-f5b126312fde `
  --role-arn arn:aws:iam::337501927775:role/HCPVaultAssumeRoleForTeam1App1 `
  --region us-east-2 `
  --endpoint https://rolesanywhere.us-east-2.amazonaws.com | ConvertFrom-Json

$env:AWS_ACCESS_KEY_ID     = $creds.AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $creds.SecretAccessKey
$env:AWS_SESSION_TOKEN     = $creds.SessionToken

aws sts get-caller-identity
aws s3 ls
