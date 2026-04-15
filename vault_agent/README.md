# Vault Agent Examples

This directory contains two examples that both use the same workflow:

- Vault Agent templating issues an X.509 client certificate from Vault PKI
- `aws_signing_helper` exchanges that certificate for AWS IAM Roles Anywhere credentials
- the script or app lists S3 buckets in AWS

## Layout

- `powershell/ListS3BucketsWithVaultAgent.ps1`: PowerShell version
- `python/list_s3_buckets_with_vault_agent.py`: Python version
- `python/requirements.txt`: Python dependencies

## Shared Prerequisites

- `vault` on `PATH`
- `aws_signing_helper` on `PATH`
- access to the Vault PKI role and AWS IAM Roles Anywhere resources created by this repository
- a Vault token that can issue certificates from the configured PKI role

The examples default to the repo’s current demo values:

- Vault namespace: `admin`
- PKI backend: `pki-aws-int`
- PKI role: `team1`
- AWS region: `us-east-2`

### Required AWS Inputs

Both examples require:

- IAM Roles Anywhere trust anchor ARN
- IAM Roles Anywhere profile ARN
- IAM role ARN

## PowerShell Example

Script:

- `.\vault_agent\powershell\ListS3BucketsWithVaultAgent.ps1`

Example:

```powershell
.\vault_agent\powershell\ListS3BucketsWithVaultAgent.ps1 `
  -VaultAddr https://<vault-host>:8200 `
  -VaultToken <vault-token> `
  -TrustAnchorArn <trust-anchor-arn> `
  -ProfileArn <profile-arn> `
  -RoleArn <role-arn>
```

Useful optional parameters:

- `-VaultNamespace admin`
- `-PkiBackend pki-aws-int`
- `-PkiRoleName team1`
- `-SpiffeUri spiffe://example/Team1/App1/vm`
- `-CertificateTtl 30m`
- `-Region us-east-2`
- `-KeepArtifacts`

## Python Example

Install dependencies first:

```powershell
python -m pip install -r .\vault_agent\python\requirements.txt
```

Script:

- `python .\vault_agent\python\list_s3_buckets_with_vault_agent.py`

Example:

```powershell
python .\vault_agent\python\list_s3_buckets_with_vault_agent.py `
  --vault-addr https://<vault-host>:8200 `
  --vault-token <vault-token> `
  --trust-anchor-arn <trust-anchor-arn> `
  --profile-arn <profile-arn> `
  --role-arn <role-arn>
```

Useful optional parameters:

- `--vault-namespace admin`
- `--pki-backend pki-aws-int`
- `--pki-role-name team1`
- `--spiffe-uri spiffe://example/Team1/App1/python`
- `--certificate-ttl 30m`
- `--region us-east-2`
- `--keep-artifacts`

## What They Do

Both examples:

1. create a temporary Vault Agent config and template
2. use Vault Agent `token_file` auto-auth with the supplied Vault token
3. render a certificate, private key, and issuing CA to a temporary directory
4. validate the rendered certificate contains the expected SPIFFE URI SAN
5. call `aws_signing_helper credential-process`
6. call AWS and list S3 buckets

By default, temporary files are deleted after the run. Use `KeepArtifacts` or `--keep-artifacts` if you want to inspect the generated files.
