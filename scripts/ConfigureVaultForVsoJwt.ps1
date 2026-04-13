param(
  [Parameter(Mandatory = $true)]
  [string]$VaultAddr,

  [Parameter(Mandatory = $true)]
  [string]$VaultToken,

  [Parameter(Mandatory = $true)]
  [string]$JwtValidationPublicKeysPath,

  [string]$VaultNamespace = "admin",

  [string]$AuthMount = "jwt",

  [string]$JwtAuthRole = "roles-anywhere-demo",

  [string]$KubernetesNamespace = "roles-anywhere-demo",

  [string]$ServiceAccountName = "roles-anywhere-demo",

  [string]$TeamName = "Team1",

  [string]$Audience = "vault",

  [string]$RoleTtl = "1h",

  [string]$BoundIssuer,

  [string]$Kubeconfig
)

$ErrorActionPreference = "Stop"

$headers = @{
  "X-Vault-Token" = $VaultToken
}

if ($VaultNamespace) {
  $headers["X-Vault-Namespace"] = $VaultNamespace
}

function Invoke-VaultApi {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Method,

    [Parameter(Mandatory = $true)]
    [string]$Path,

    [object]$Body
  )

  $params = @{
    Method      = $Method
    Uri         = "$VaultAddr/v1/$Path"
    Headers     = $headers
    ContentType = "application/json"
  }

  if ($null -ne $Body) {
    $params["Body"] = $Body | ConvertTo-Json -Depth 10 -Compress
  }

  Invoke-RestMethod @params
}

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

if ([string]::IsNullOrWhiteSpace($BoundIssuer)) {
  $discovery = Invoke-KubectlRaw -RawPath "/.well-known/openid-configuration" | ConvertFrom-Json
  $BoundIssuer = $discovery.issuer
}

$pemFile = Get-Content -Raw -LiteralPath $JwtValidationPublicKeysPath
$pemMatches = [regex]::Matches($pemFile, '-----BEGIN PUBLIC KEY-----(?:.|\r|\n)+?-----END PUBLIC KEY-----')

if ($pemMatches.Count -eq 0) {
  throw "No PEM public keys were found in $JwtValidationPublicKeysPath"
}

$pemBlocks = @($pemMatches | ForEach-Object { $_.Value.Trim() })
$policyName = "{0}-iam-roles-anywhere-issue-certs" -f $TeamName.ToLowerInvariant()
$boundSubject = "system:serviceaccount:${KubernetesNamespace}:${ServiceAccountName}"

$auths = Invoke-VaultApi -Method "GET" -Path "sys/auth" -Body $null
$authMountKey = "$AuthMount/"

if ($auths.PSObject.Properties.Name -notcontains $authMountKey) {
  Invoke-VaultApi -Method "POST" -Path "sys/auth/$AuthMount" -Body @{
    type = "jwt"
  } | Out-Null

  Write-Output "Enabled Vault auth mount: $AuthMount"
}
else {
  Write-Output "Vault auth mount already exists: $AuthMount"
}

Invoke-VaultApi -Method "POST" -Path "auth/$AuthMount/config" -Body @{
  bound_issuer            = $BoundIssuer
  jwt_validation_pubkeys  = $pemBlocks
} | Out-Null

Invoke-VaultApi -Method "POST" -Path "auth/$AuthMount/role/$JwtAuthRole" -Body @{
  role_type       = "jwt"
  bound_audiences = @($Audience)
  user_claim      = "sub"
  bound_subject   = $boundSubject
  policies        = @($policyName)
  ttl             = $RoleTtl
} | Out-Null

Write-Output "Configured Vault JWT auth mount: $AuthMount"
Write-Output "Configured Vault JWT auth role: $JwtAuthRole"
Write-Output "Bound issuer: $BoundIssuer"
Write-Output "Bound audience: $Audience"
Write-Output "Bound subject: $boundSubject"
Write-Output "Attached policy: $policyName"
Write-Output "Loaded JWT validation public keys: $($pemBlocks.Count)"
