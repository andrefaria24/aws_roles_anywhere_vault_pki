# AWS IAM Roles Anywhere + HashiCorp Vault Demo

This repository demonstrates how HashiCorp Vault can issue X.509 certificates for workloads that need to authenticate to AWS by using IAM Roles Anywhere.

The demo is split into two Terraform stacks with clear ownership:

- The Vault team owns [`iac/vault`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/README.md), which operates the PKI hierarchy used to issue workload certificates.
- The Cloud team owns [`iac/aws`](C:/Dev/aws_roles_anywhere_vault_pki/iac/aws/README.md), which configures IAM Roles Anywhere, IAM roles, and team-to-role mappings in AWS.

## What This Demo Shows

1. Vault creates a root CA and an intermediate CA dedicated to AWS authentication.
2. The signed Vault intermediate certificate is used as the AWS IAM Roles Anywhere trust anchor.
3. AWS creates IAM roles that trust `rolesanywhere.amazonaws.com`, with conditions that match URI SAN values in the client certificate.
4. Vault issues a short-lived certificate to a workload with a SPIFFE-style URI SAN such as `spiffe://example/Team1/App1/test`.
5. `aws_signing_helper` exchanges that certificate for temporary AWS credentials.
6. The workload uses those temporary credentials to call AWS APIs, such as listing S3 buckets.

## Repository Layout

- [`iac/vault`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/README.md): Vault PKI configuration and issuer certificate export.
- [`iac/aws`](C:/Dev/aws_roles_anywhere_vault_pki/iac/aws/README.md): AWS IAM Roles Anywhere trust anchor, profiles, IAM roles, and Vault-side team/app issuance mappings.
- [`scripts/IssueCertificate.ps1`](C:/Dev/aws_roles_anywhere_vault_pki/scripts/IssueCertificate.ps1): Requests a workload certificate from Vault and writes the cert, key, and issuing CA locally.
- [`scripts/ListS3Buckets.ps1`](C:/Dev/aws_roles_anywhere_vault_pki/scripts/ListS3Buckets.ps1): Uses `aws_signing_helper` to obtain temporary AWS credentials and runs `aws s3 ls`.

## Team Handoff

The main integration point between the two stacks is the Vault intermediate certificate:

- The Vault stack writes the signed intermediate certificate to `iac/vault/certs/vault_intermediate_cert.pem`.
- The AWS trust anchor stack reads `iac/aws/rolesanywhere/trust_anchor/certs/vault_intermediate_cert.pem`.

In practice, the Vault team is responsible for producing and handing off the intermediate CA certificate, and the Cloud team is responsible for using that certificate in the AWS trust anchor configuration.

## Typical Demo Flow

1. Apply the Vault stack.
2. Share or copy the signed intermediate certificate to the AWS trust anchor path expected by the AWS stack.
3. Apply the AWS stack with the desired `team_apps` mapping.
4. Issue a workload certificate with [`scripts/IssueCertificate.ps1`](C:/Dev/aws_roles_anywhere_vault_pki/scripts/IssueCertificate.ps1).
5. Use [`scripts/ListS3Buckets.ps1`](C:/Dev/aws_roles_anywhere_vault_pki/scripts/ListS3Buckets.ps1) or an AWS CLI profile backed by `aws_signing_helper` to confirm the workload can assume the intended role and access AWS.

For module-specific details, inputs, outputs, and operational responsibilities, use the module READMEs linked above.
