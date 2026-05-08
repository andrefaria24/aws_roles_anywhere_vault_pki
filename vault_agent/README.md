# Vault Agent Examples

This directory contains two examples that both:

- use a bootstrap client certificate with Vault `auth/cert`
- use Vault Agent templating to issue an X.509 client certificate from Vault PKI
- use `aws_signing_helper` to exchange that certificate for AWS IAM Roles Anywhere credentials
- list S3 buckets in AWS

## Layout

- `powershell/ListS3BucketsWithVaultAgent.ps1`: PowerShell version
- `python/list_s3_buckets_with_vault_agent.py`: Python version
- `python/requirements.txt`: Python dependencies

## Shared Prerequisites

- `vault` on `PATH`
- `aws_signing_helper` on `PATH`
- access to the Vault PKI role and AWS IAM Roles Anywhere resources created by this repository
- if you are using HCP Vault Dedicated, TLS certificate auth must be enabled for the cluster before `auth/cert` can work

The examples default to the repo’s current demo values:

- Vault namespace: `admin`
- Vault auth path: `auth/cert`
- Vault cert-auth role name: `team1-vm`
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
  -TrustAnchorArn <trust-anchor-arn> `
  -ProfileArn <profile-arn> `
  -RoleArn <role-arn>
```

Before running the PowerShell example from the repo root, copy the bootstrap client certificate and private key into:

- `.\certs\team1_vm_bootstrap_client_cert.pem`
- `.\certs\team1_vm_bootstrap_client_key.pem`

Useful optional parameters:

- `-VaultNamespace admin`
- `-VaultAuthPath auth/cert`
- `-VaultAuthCertName team1-vm`
- `-VaultClientCert .\certs\team1_vm_bootstrap_client_cert.pem`
- `-VaultClientKey .\certs\team1_vm_bootstrap_client_key.pem`
- `-VaultCaCert .\path\to\vault-server-ca.pem`
- `-VaultAgentTimeoutSeconds 20`
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
  --trust-anchor-arn <trust-anchor-arn> `
  --profile-arn <profile-arn> `
  --role-arn <role-arn>
```

If you run the Python example from `.\vault_agent\python`, copy the bootstrap client certificate and private key into:

- `.\certs\team1_vm_bootstrap_client_cert.pem`
- `.\certs\team1_vm_bootstrap_client_key.pem`

Useful optional parameters:

- `--vault-namespace admin`
- `--vault-auth-path auth/cert`
- `--vault-auth-cert-name team1-vm`
- `--vault-client-cert .\certs\team1_vm_bootstrap_client_cert.pem`
- `--vault-client-key .\certs\team1_vm_bootstrap_client_key.pem`
- `--vault-ca-cert .\path\to\vault-server-ca.pem`
- `--vault-agent-timeout-seconds 20`
- `--pki-backend pki-aws-int`
- `--pki-role-name team1`
- `--spiffe-uri spiffe://example/Team1/App1/python`
- `--certificate-ttl 30m`
- `--region us-east-2`
- `--keep-artifacts`

## What They Do

Both examples:

1. create a temporary Vault Agent config and template
2. authenticate Vault Agent with the configured login method for that example
3. render a certificate, private key, and issuing CA to a temporary directory
4. validate the rendered certificate contains the expected SPIFFE URI SAN
5. call `aws_signing_helper credential-process`
6. call AWS and list S3 buckets

By default, temporary files are deleted after the run. Use `KeepArtifacts` or `--keep-artifacts` if you want to inspect the generated files.

If Vault Agent cannot authenticate, both examples now time out after 20 seconds by default and print the captured Vault Agent output instead of retrying forever.
