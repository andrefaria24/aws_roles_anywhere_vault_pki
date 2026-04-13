param(
  [string]$Kubeconfig,

  [string]$OutputPath = ".\\jwt_validation_pubkeys.pem"
)

$ErrorActionPreference = "Stop"

function Invoke-KubectlRaw {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RawPath
  )

  $args = @()

  if (-not [string]::IsNullOrWhiteSpace($Kubeconfig)) {
    $args += "--kubeconfig=$Kubeconfig"
  }

  $args += @("get", "--raw", $RawPath)

  $result = & kubectl @args

  if ($LASTEXITCODE -ne 0) {
    throw "kubectl failed while reading path: $RawPath"
  }

  $result
}

function Convert-Base64UrlToBytes {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Value
  )

  $padded = $Value.Replace('-', '+').Replace('_', '/')

  switch ($padded.Length % 4) {
    2 { $padded += "==" }
    3 { $padded += "=" }
  }

  [Convert]::FromBase64String($padded)
}

$discovery = Invoke-KubectlRaw -RawPath "/.well-known/openid-configuration" | ConvertFrom-Json
$jwksUri = [Uri]$discovery.jwks_uri
$jwks = Invoke-KubectlRaw -RawPath $jwksUri.PathAndQuery | ConvertFrom-Json

$pemBlocks = New-Object System.Collections.Generic.List[string]

foreach ($key in $jwks.keys) {
  if ($key.kty -ne "RSA") {
    Write-Warning "Skipping unsupported JWK type '$($key.kty)' with kid '$($key.kid)'."
    continue
  }

  $rsa = [System.Security.Cryptography.RSA]::Create()
  $rsa.ImportParameters([System.Security.Cryptography.RSAParameters]@{
      Modulus  = Convert-Base64UrlToBytes -Value $key.n
      Exponent = Convert-Base64UrlToBytes -Value $key.e
    })

  $pemBlocks.Add($rsa.ExportSubjectPublicKeyInfoPem().Trim())
  $rsa.Dispose()
}

if ($pemBlocks.Count -eq 0) {
  throw "No RSA signing keys were found in the Kubernetes JWKS response."
}

$pemDocument = ($pemBlocks -join [Environment]::NewLine) + [Environment]::NewLine
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $PWD).Path + "\" + ($OutputPath -replace '^\.[\\/]',''), $pemDocument)

Write-Output "Issuer: $($discovery.issuer)"
Write-Output "JWKS URI: $($discovery.jwks_uri)"
Write-Output "PEM output: $OutputPath"
Write-Output "Exported RSA public keys: $($pemBlocks.Count)"
