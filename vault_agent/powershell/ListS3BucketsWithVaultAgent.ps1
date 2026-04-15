param(
  [Parameter(Mandatory = $true)]
  [string]$VaultAddr,

  [Parameter(Mandatory = $true)]
  [string]$VaultToken,

  [Parameter(Mandatory = $true)]
  [string]$TrustAnchorArn,

  [Parameter(Mandatory = $true)]
  [string]$ProfileArn,

  [Parameter(Mandatory = $true)]
  [string]$RoleArn,

  [string]$VaultNamespace = "admin",

  [string]$PkiBackend = "pki-aws-int",

  [string]$PkiRoleName = "team1",

  [string]$SpiffeUri = "spiffe://example/Team1/App1/vm",

  [string]$CertificateTtl = "30m",

  [string]$Region = "us-east-2",

  [string]$Endpoint,

  [string]$VaultAgentPath = "vault",

  [string]$AwsSigningHelperPath = "aws_signing_helper",

  [string]$AwsCliPath = "aws",

  [string]$WorkingDirectory,

  [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"

function Resolve-Executable {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $command = Get-Command $Name -ErrorAction SilentlyContinue

  if (-not $command) {
    throw "Required executable not found on PATH: $Name"
  }

  $command.Source
}

function Convert-ToAgentPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  ([System.IO.Path]::GetFullPath($Path)).Replace('\', '/')
}

function Write-Utf8File {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Content
  )

  $parent = Split-Path -Parent $Path

  if ($parent) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Assert-FileExists {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Expected file was not created: $Path"
  }
}

if ([string]::IsNullOrWhiteSpace($Endpoint)) {
  $Endpoint = "https://rolesanywhere.$Region.amazonaws.com"
}

$vaultAgentExe = Resolve-Executable -Name $VaultAgentPath
$awsSigningHelperExe = Resolve-Executable -Name $AwsSigningHelperPath
$awsCliExe = Resolve-Executable -Name $AwsCliPath

if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
  $WorkingDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("vault-agent-rolesanywhere-" + [guid]::NewGuid().ToString("N"))
}

$workingDirFull = [System.IO.Path]::GetFullPath($WorkingDirectory)
$renderDir = Join-Path -Path $workingDirFull -ChildPath "rendered"

$tokenFile = Join-Path -Path $workingDirFull -ChildPath "vault-token.txt"
$sinkFile = Join-Path -Path $workingDirFull -ChildPath "auto-auth-token.txt"
$templateFile = Join-Path -Path $workingDirFull -ChildPath "issue-cert.ctmpl"
$configFile = Join-Path -Path $workingDirFull -ChildPath "vault-agent.hcl"
$renderMarker = Join-Path -Path $workingDirFull -ChildPath "rendered.txt"

$certPath = Join-Path -Path $renderDir -ChildPath "cert.pem"
$keyPath = Join-Path -Path $renderDir -ChildPath "key.pem"
$caPath = Join-Path -Path $renderDir -ChildPath "issuing_ca.pem"

New-Item -ItemType Directory -Path $renderDir -Force | Out-Null
Write-Utf8File -Path $tokenFile -Content ($VaultToken + [Environment]::NewLine)

$certRequestPath = "$PkiBackend/issue/$PkiRoleName"
$certPathAgent = Convert-ToAgentPath -Path $certPath
$keyPathAgent = Convert-ToAgentPath -Path $keyPath
$caPathAgent = Convert-ToAgentPath -Path $caPath

$templateContent = @"
{{- with pkiCert "$certRequestPath" "uri_sans=$SpiffeUri" "ttl=$CertificateTtl" -}}
{{ .Data.Key | writeToFile "$keyPathAgent" "" "" "0600" }}
{{ .Data.CA | writeToFile "$caPathAgent" "" "" "0644" }}
{{ .Data.Cert | writeToFile "$certPathAgent" "" "" "0644" }}
{{ .Data.CA | writeToFile "$certPathAgent" "" "" "0644" "append" }}
rendered
{{- end -}}
"@

Write-Utf8File -Path $templateFile -Content $templateContent

$vaultAgentExeAgent = Convert-ToAgentPath -Path $vaultAgentExe
$tokenFileAgent = Convert-ToAgentPath -Path $tokenFile
$sinkFileAgent = Convert-ToAgentPath -Path $sinkFile
$templateFileAgent = Convert-ToAgentPath -Path $templateFile
$renderMarkerAgent = Convert-ToAgentPath -Path $renderMarker

$namespaceLine = ""

if (-not [string]::IsNullOrWhiteSpace($VaultNamespace)) {
  $namespaceLine = "  namespace = `"$VaultNamespace`""
}

$agentConfig = @"
exit_after_auth = true

vault {
  address = "$VaultAddr"
$namespaceLine
}

auto_auth {
  method "token_file" {
    config = {
      token_file_path = "$tokenFileAgent"
    }
  }

  sink "file" {
    config = {
      path = "$sinkFileAgent"
    }
  }
}

template_config {
  exit_on_retry_failure = true
}

template {
  source = "$templateFileAgent"
  destination = "$renderMarkerAgent"
  error_on_missing_key = true
}
"@

Write-Utf8File -Path $configFile -Content $agentConfig

try {
  & $vaultAgentExe agent "-config=$configFile"

  if ($LASTEXITCODE -ne 0) {
    throw "Vault Agent exited with code $LASTEXITCODE"
  }

  Assert-FileExists -Path $certPath
  Assert-FileExists -Path $keyPath
  Assert-FileExists -Path $caPath

  $dump = certutil -dump $certPath 2>&1 | Out-String
  $hasSanSection = $dump -match "Subject Alternative Name"
  $hasUri = $dump -match [regex]::Escape($SpiffeUri)

  if (-not $hasSanSection -or -not $hasUri) {
    throw "Vault Agent rendered a certificate without the expected SAN URI. Requested URI: $SpiffeUri`n`nCertificate dump:`n$dump"
  }

  $creds = & $awsSigningHelperExe credential-process `
    --certificate $certPath `
    --private-key $keyPath `
    --trust-anchor-arn $TrustAnchorArn `
    --profile-arn $ProfileArn `
    --role-arn $RoleArn `
    --region $Region `
    --endpoint $Endpoint | ConvertFrom-Json

  $env:AWS_ACCESS_KEY_ID = $creds.AccessKeyId
  $env:AWS_SECRET_ACCESS_KEY = $creds.SecretAccessKey
  $env:AWS_SESSION_TOKEN = $creds.SessionToken

  Write-Output "Issued certificate with SAN URI: $SpiffeUri"
  Write-Output "Certificate: $certPath"
  Write-Output "Private key: $keyPath"
  Write-Output "Issuing CA: $caPath"
  Write-Output "AWS caller identity:"

  & $awsCliExe sts get-caller-identity

  if ($LASTEXITCODE -ne 0) {
    throw "aws sts get-caller-identity failed with code $LASTEXITCODE"
  }

  Write-Output ""
  Write-Output "S3 buckets:"

  & $awsCliExe s3 ls

  if ($LASTEXITCODE -ne 0) {
    throw "aws s3 ls failed with code $LASTEXITCODE"
  }
}
finally {
  if (-not $KeepArtifacts) {
    Remove-Item -LiteralPath $workingDirFull -Recurse -Force -ErrorAction SilentlyContinue
  }
}
