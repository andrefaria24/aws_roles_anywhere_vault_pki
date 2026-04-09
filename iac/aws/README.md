# AWS Module

This module is owned by the Cloud team.

Its job is to configure the AWS side of the demo so workloads with Vault-issued certificates can authenticate to AWS through IAM Roles Anywhere.

## What This Module Does

The AWS stack orchestrates three areas:

- It creates the IAM Roles Anywhere trust anchor from the Vault intermediate CA certificate in [`rolesanywhere/trust_anchor/certs/vault_intermediate_cert.pem`](C:/Dev/aws_roles_anywhere_vault_pki/iac/aws/rolesanywhere/trust_anchor/certs/vault_intermediate_cert.pem).
- It creates one IAM role per team/application pair. Each role trusts `rolesanywhere.amazonaws.com` and requires the certificate URI SAN to match `spiffe://example/<Team>/<App>/*`.
- It creates one IAM Roles Anywhere profile per team, attaching the IAM roles for that team.

This stack also writes supporting Vault configuration so the certificate issuance side stays aligned with AWS access rules:

- A Vault PKI role per team under `pki-aws-int`.
- A Vault policy per team that grants access to issue certificates from the corresponding PKI role.

## Why The Cloud Team Owns It

This module defines the AWS authentication boundary:

- Which IAM roles can be assumed.
- Which certificate URI SANs are trusted for each role.
- Which IAM Roles Anywhere profiles expose those roles.

Because those concerns map directly to AWS identity and access management, they should be operated by the Cloud team.

## Inputs

The main inputs are defined in [`variables.tf`](C:/Dev/aws_roles_anywhere_vault_pki/iac/aws/variables.tf):

- `aws_region`: AWS region for the demo. Defaults to `us-east-2`.
- `aws_profile`: Local AWS CLI profile Terraform should use.
- `aws_credentials_file_location`: Credentials file used by the AWS provider.
- `team_apps`: Map of teams to application names. This drives IAM role creation and the matching Vault PKI roles/policies.
- `vault_address`: Vault address used by the Vault provider.
- `vault_token`: Vault token used to create the Vault PKI roles and Vault policies required by this stack.

Example shape for `team_apps`:

```hcl
team_apps = {
  Team1 = ["App1", "App2"]
  Team2 = ["App3"]
}
```

## Outputs

The module exposes:

- Role names and ARNs for each team/application pair.
- Role ARNs grouped by team.
- IAM Roles Anywhere profile names, ARNs, and IDs grouped by team.

See [`outputs.tf`](C:/Dev/aws_roles_anywhere_vault_pki/iac/aws/outputs.tf) for the exact output names.

## Operational Notes

- The trust anchor expects the Vault intermediate certificate to exist at [`rolesanywhere/trust_anchor/certs/vault_intermediate_cert.pem`](C:/Dev/aws_roles_anywhere_vault_pki/iac/aws/rolesanywhere/trust_anchor/certs/vault_intermediate_cert.pem).
- The current implementation assumes the Vault PKI backend path is `pki-aws-int`.
- The current implementation uses SPIFFE-style URI SAN patterns in the form `spiffe://example/<Team>/<App>/*`.
- Because this stack writes Vault resources as well as AWS resources, Terraform execution requires valid access to both AWS and Vault.
