# Python Certificate Auth Flow

This diagram shows the end-to-end flow for the Python example:

- how the bootstrap client certificate is created
- how the Python workload authenticates to Vault with that certificate
- how Vault issues the AWS workload certificate
- how AWS IAM Roles Anywhere returns temporary credentials

```mermaid
flowchart TD
    A[Terraform in iac/vault] --> B[Vault root CA<br/>pki-aws-root]
    B --> C[Vault auth bootstrap intermediate CA<br/>pki-auth-cert-int]
    B --> D[Vault AWS workload intermediate CA<br/>pki-aws-int]

    C --> E[Issue bootstrap client cert and key<br/>CN=team1-vm]
    E --> F[Operator copies bootstrap cert and key<br/>to vault_agent/python/certs]

    D --> G[Export workload intermediate cert]
    G --> H[AWS IAM Roles Anywhere trust anchor<br/>trusts Vault workload intermediate]

    F --> I[Python script starts Vault Agent]
    I --> J[Vault Agent auth/cert login<br/>auth/cert role: team1-vm]
    J --> K[Vault validates presented client cert<br/>against pki-auth-cert-int trust]
    K --> L[Vault issues short-lived Vault token<br/>policy allows pki-aws-int/issue/team1]

    L --> M[Vault Agent template calls pkiCert<br/>pki-aws-int/issue/team1]
    M --> N[Vault issues short-lived AWS workload cert<br/>with SPIFFE URI SAN]
    N --> O[Python script validates expected URI SAN]

    O --> P[aws_signing_helper credential-process]
    H --> P
    P --> Q[AWS IAM Roles Anywhere verifies:<br/>issuer chain + trust anchor + role/profile + URI SAN]
    Q --> R[STS temporary AWS credentials]
    R --> S[boto3 calls AWS APIs]
    S --> T[List S3 buckets]
```

## Sequence Summary

1. Terraform creates two separate trust chains in Vault:
   - `pki-auth-cert-int` for Vault `auth/cert` bootstrap login
   - `pki-aws-int` for AWS workload certificates
2. Terraform issues the bootstrap `team1-vm` client certificate from `pki-auth-cert-int`.
3. That bootstrap cert and key are copied into the Python example's `certs` directory.
4. Vault Agent presents the bootstrap cert to `auth/cert/login`.
5. Vault returns a Vault token scoped to issuing certificates from `pki-aws-int/issue/team1`.
6. Vault Agent uses that token to render a new short-lived workload certificate for AWS.
7. `aws_signing_helper` exchanges the workload certificate for temporary AWS credentials through IAM Roles Anywhere.
8. `boto3` uses those temporary credentials to access AWS resources.

## Trust Separation

- `pki-auth-cert-int` is only for authenticating the workload to Vault.
- `pki-aws-int` is only for authenticating the workload to AWS IAM Roles Anywhere.
- Keeping those intermediates separate avoids mixing Vault login trust with AWS workload trust.
