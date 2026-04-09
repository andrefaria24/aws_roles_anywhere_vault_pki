# Vault Module

This module is owned by the Vault team.

Its job is to stand up the PKI hierarchy used to issue workload certificates that AWS IAM Roles Anywhere will trust.

## What This Module Does

The Vault stack creates:

- A root PKI mount at `pki-aws-root`.
- An intermediate PKI mount at `pki-aws-int`.
- An internally generated root CA certificate.
- An internally generated intermediate CA certificate signed by the Vault root.

After the intermediate certificate is signed, the module writes it to [`certs/vault_intermediate_cert.pem`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/certs/vault_intermediate_cert.pem) so it can be handed to the Cloud team and used as the AWS IAM Roles Anywhere trust anchor certificate.

## Why The Vault Team Owns It

This module defines and operates the certificate authority used by workloads:

- PKI mount lifecycle.
- Root and intermediate CA issuance.
- Certificate trust material that must be distributed to AWS.

Those responsibilities belong with the team operating Vault and the PKI service.

## Inputs

The main inputs are defined in [`variables.tf`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/variables.tf):

- `vault_address`: Vault address Terraform should target.
- `vault_token`: Vault token Terraform should use.
- `domain_name`: Common name base used for the root and intermediate CAs. Defaults to `example.com`.

## Outputs

The module exposes:

- `roles_anywhere_issuer_certificate`: The signed intermediate certificate.
- `vault_pki_backend`: The backend path for the intermediate PKI mount, currently `pki-aws-int`.

See [`outputs.tf`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/outputs.tf) for the exact definitions.

## Operational Notes

- The intermediate PKI backend is the certificate source used later by workload issuance flows.
- The exported certificate in [`certs/vault_intermediate_cert.pem`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/certs/vault_intermediate_cert.pem) is the handoff artifact consumed by the AWS trust anchor stack.
- The current demo keeps certificate issuance roles outside this module. Those per-team issuance roles are created by the AWS stack so the AWS-side role mappings and Vault issuance rules stay aligned.
