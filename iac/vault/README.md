# Vault Module

This module is owned by the Vault team.

Its job is to stand up the PKI hierarchy used to issue workload certificates that AWS IAM Roles Anywhere will trust.

## What This Module Does

The Vault stack creates:

- A root PKI mount at `pki-aws-root`.
- An intermediate PKI mount at `pki-aws-int`.
- A separate intermediate PKI mount at `pki-auth-cert-int` for Vault cert-auth bootstrap certificates.
- An internally generated root CA certificate.
- Two internally generated intermediate CA certificates signed by the Vault root.
- A Vault cert auth mount at `auth/cert`.
- A `team1-vm` cert-auth role that trusts the dedicated cert-auth intermediate and can mint a Vault token scoped to issuing `team1` workload certificates.
- A constrained PKI role and an exported demo client certificate/key pair for the `team1-vm` bootstrap workload.

After the intermediate certificate is signed, the module writes it to [`certs/vault_intermediate_cert.pem`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/certs/vault_intermediate_cert.pem) so it can be handed to the Cloud team and used as the AWS IAM Roles Anywhere trust anchor certificate.

## Why The Vault Team Owns It

This module defines and operates the certificate authority used by workloads:

- PKI mount lifecycle.
- Root and intermediate CA issuance.
- Certificate trust material that must be distributed to AWS.
- Bootstrap client certificate trust material for Vault `auth/cert`.

Those responsibilities belong with the team operating Vault and the PKI service.

## Inputs

The main inputs are defined in [`variables.tf`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/variables.tf):

- `vault_address`: Vault address Terraform should target.
- `vault_token`: Vault token Terraform should use.
- `domain_name`: Common name base used for the root and intermediate CAs. Defaults to `example.com`.
- `team1_vm_bootstrap_common_name`: Common name used for the exported `team1-vm` bootstrap client certificate. Defaults to `team1-vm`.
- `team1_vm_bootstrap_certificate_ttl`: TTL used for the exported `team1-vm` bootstrap client certificate. Defaults to `720h`.

## Outputs

The module exposes:

- `roles_anywhere_issuer_certificate`: The signed intermediate certificate.
- `vault_pki_backend`: The backend path for the intermediate PKI mount, currently `pki-aws-int`.
- `vault_cert_auth_backend`: The backend path for the cert auth mount, currently `cert`.
- `vault_cert_auth_pki_backend`: The dedicated PKI backend path for cert-auth bootstrap certificates, currently `pki-auth-cert-int`.
- `team1_vm_cert_auth_role`: The Vault cert-auth role name for the bootstrap VM workload.
- `team1_vm_cert_auth_policy`: The Vault policy name attached to the bootstrap VM cert-auth role.
- `team1_vm_bootstrap_pki_role`: The PKI role used to issue the demo `team1-vm` client certificate.
- `team1_vm_bootstrap_client_cert_path`: Local path where Terraform writes the demo client certificate chain.
- `team1_vm_bootstrap_client_key_path`: Local path where Terraform writes the demo client private key.
- `team1_vm_bootstrap_client_ca_path`: Local path where Terraform writes the issuing CA certificate for the demo client certificate.

See [`outputs.tf`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/outputs.tf) for the exact definitions.

## Operational Notes

- The intermediate PKI backend is the certificate source used later by workload issuance flows.
- The exported certificate in [`certs/vault_intermediate_cert.pem`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/certs/vault_intermediate_cert.pem) is the handoff artifact consumed by the AWS trust anchor stack.
- The exported bootstrap client certificate is written to [`certs/team1_vm_bootstrap_client_cert.pem`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/certs/team1_vm_bootstrap_client_cert.pem) and the private key to [`certs/team1_vm_bootstrap_client_key.pem`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/certs/team1_vm_bootstrap_client_key.pem).
- The `team1-vm` cert-auth role is a bootstrap login path into Vault. Its trust anchor is the dedicated `pki-auth-cert-int` intermediate, not the AWS IAM Roles Anywhere intermediate.
- The current demo still keeps the PKI issuance role definitions outside this module. Those per-team issuance roles are created by the AWS stack so the AWS-side role mappings and Vault issuance rules stay aligned.
