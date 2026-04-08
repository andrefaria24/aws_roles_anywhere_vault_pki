param(
  [Parameter(Mandatory = $true)]
  [string]$VaultAddr,

  [Parameter(Mandatory = $true)]
  [string]$VaultToken,

  [string]$VaultNamespace = "admin",

  [string]$PkiRoleName = "team1-dev",

  [string]$SpiffeUri = "spiffe://example/team1/dev/app",

  [string]$CertPath = ".\\cert.pem",

  [string]$KeyPath = ".\\key.pem",

  [string]$CaPath = ".\\issuing_ca.pem"
)

$ErrorActionPreference = "Stop"

$body = @{
  uri_sans = $SpiffeUri
} | ConvertTo-Json -Compress

$headers = @{
  "X-Vault-Token"     = $VaultToken
  "X-Vault-Namespace" = $VaultNamespace
}

$response = Invoke-RestMethod `
  -Method Post `
  -Uri "$VaultAddr/v1/pki-aws-2-int/issue/$PkiRoleName" `
  -Headers $headers `
  -ContentType "application/json" `
  -Body $body

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $PWD).Path + "\" + ($CertPath -replace '^\.[\\/]',''), $response.data.certificate + [Environment]::NewLine)
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $PWD).Path + "\" + ($KeyPath -replace '^\.[\\/]',''), $response.data.private_key + [Environment]::NewLine)
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $PWD).Path + "\" + ($CaPath -replace '^\.[\\/]',''), $response.data.issuing_ca + [Environment]::NewLine)

$dump = certutil -dump $CertPath 2>&1 | Out-String
$hasSanSection = $dump -match "Subject Alternative Name"
$hasUri = $dump -match [regex]::Escape($SpiffeUri)

if (-not $hasSanSection -or -not $hasUri) {
  throw "Vault returned a certificate without the expected SAN URI. Requested URI: $SpiffeUri`n`nCertificate dump:`n$dump"
}

Write-Output "Issued certificate with SAN URI: $SpiffeUri"
Write-Output "Certificate: $CertPath"
Write-Output "Private key: $KeyPath"
Write-Output "Issuing CA: $CaPath"
