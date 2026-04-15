# AWS IAM Roles Anywhere + HashiCorp Vault Example

This repository demonstrates how HashiCorp Vault can issue X.509 certificates for workloads that need to authenticate to AWS by using IAM Roles Anywhere.

The demo is split into two Terraform stacks:

- The Vault team owns [`iac/vault`](./iac/vault/), which operates the PKI hierarchy used to issue workload certificates.
- The Cloud team owns [`iac/aws`](./iac/aws/), which configures IAM Roles Anywhere, IAM roles, and team-to-role mappings in AWS.

## What This Example Demonstrates

1. Vault creates a root CA and an intermediate CA dedicated to AWS authentication.
2. The signed Vault intermediate certificate is used as the AWS IAM Roles Anywhere trust anchor.
3. AWS creates IAM roles that trust `rolesanywhere.amazonaws.com`, with conditions that match URI SAN values in the client certificate.
4. Vault issues a short-lived certificate to a workload with a SPIFFE-style URI SAN such as `spiffe://example/Team1/App1/test`.
5. `aws_signing_helper` exchanges that certificate for temporary AWS credentials.
6. The workload uses those temporary credentials to call AWS APIs.

## Repository Layout

- [`iac/vault`](./iac/vault/): Vault PKI configuration and issuer certificate export.
- [`iac/aws`](./iac/aws/): AWS IAM Roles Anywhere trust anchor, profiles, IAM roles, and Vault-side team/app issuance mappings.
- [`k8s/roles-anywhere-hello-world`](./k8s/roles-anywhere-hello-world/): VSO-based Kubernetes hello-world app that requests a Vault-issued certificate and uses IAM Roles Anywhere through `aws_signing_helper`.
- [`vault_agent/`](./vault_agent/): Example VM-oriented Python and PowerShell workflows that utilize Vault Agent templating to issue a client certificate and authenticate to AWS IAM Roles Anywhere to list S3 buckets.
- [`scripts/`](./scripts/): Ad-hoc scripts that perform actions related to k8s and vault configuration & certificate requests.

## Team Handoff

The main integration point between the two stacks is the Vault intermediate certificate:

- The Vault stack writes the signed intermediate certificate to `iac/vault/certs/vault_intermediate_cert.pem`.
- The AWS trust anchor stack reads `iac/aws/rolesanywhere/trust_anchor/certs/vault_intermediate_cert.pem`.

In practice, the Vault team is responsible for producing and handing off the intermediate CA certificate, and the Cloud team is responsible for using that certificate in the AWS trust anchor configuration.

## Example Flow

1. Apply the Vault iac stack.
2. Share or copy the signed intermediate certificate to the AWS trust anchor path expected by the AWS stack.
3. Apply the AWS stack with the desired `team_apps` mapping.
4. Issue a workload certificate with [`scripts/IssueCertificate.ps1`](./scripts/IssueCertificate.ps1).
5. Deploy the Kubernetes example in [`k8s/roles-anywhere-hello-world`](./k8s/roles-anywhere-hello-world/) to have VSO issue the workload certificate inside the cluster and vend AWS credentials to the pod.
6. Execute the ad-hoc script examples in [`vault_agent/`](./vault_agent/) to render certificates via the vault agent.

For module-specific details, inputs, outputs, and operational responsibilities, use the module READMEs.