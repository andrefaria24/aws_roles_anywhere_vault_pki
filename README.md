# AWS Roles Anywhere + Vault (Hub-and-Spoke Example)

This repository demonstrates a working reference implementation of using **HashiCorp Vault PKI** with **AWS Roles Anywhere** to enable **machine authentication to AWS using X.509 certificates**.

The design uses a **hub-and-spoke AWS account model**, where a central (hub) account hosts Roles Anywhere resources and workloads ultimately access resources in spoke accounts.

---

## What Problem This Solves

Traditional approaches to AWS access often rely on:

- Long-lived IAM access keys
- Credential brokering (e.g., Vault AWS Secrets Engine)
- Human SSO flows reused for machines (e.g., saml2aws)

This implementation replaces those patterns with:

> **Short-lived, identity-based authentication using certificates**

- No static AWS credentials
- No Vault → AWS API dependency
- AWS IAM enforces authorization

---

## Architecture Overview

High-level flow:

1. Workload authenticates to Vault (AppRole)
2. Vault issues a short-lived X.509 certificate
3. Certificate contains a SPIFFE URI identity
4. Workload uses `aws_signing_helper` to authenticate to AWS Roles Anywhere
5. AWS validates the certificate against the Trust Anchor (CA)
6. IAM evaluates the identity and returns temporary credentials
7. Hub role assumes a spoke role for resource access

Key concept:

> Vault = Identity Provider  
> AWS IAM = Authorization / Enforcement

---

## Repository Structure

### Root (Hub)

- Vault configuration (PKI, AppRole, policies)
- AWS Roles Anywhere:
  - Trust Anchor
  - Profiles
- Hub IAM roles (assumed via Roles Anywhere)

### Spoke Modules

Each `_team*` folder represents a separate AWS account:

- IAM role trusting the hub role
- Optional permissions (readonly/admin)
- Test S3 bucket

---

## Apply Order

### 1. Deploy hub (root module)

```bash
terraform init
terraform apply
```

### 2. Deploy spoke accounts

```bash
cd _team1-dev
terraform init
terraform apply

cd ../_team1-prod
terraform init
terraform apply

cd ../_team2-dev
terraform init
terraform apply
```

---

## End-to-End Test Flow

Each team folder (`_team*`) contains a helper script (e.g., `team1-dev-testing.sh`) that performs the full flow automatically:

1. Generate AppRole `secret_id`
2. Authenticate to Vault (AppRole login)
3. Issue PKI certificate
4. Authenticate to AWS via Roles Anywhere
5. Assume spoke role
6. Execute AWS command (`aws s3 ls`)

These scripts are intended to demonstrate the **complete end-to-end machine authentication flow** with minimal manual steps.

---

## Identity Model (Important)

This implementation uses **SPIFFE URIs in the certificate SAN** for authorization, not `common_name`.

IAM Roles Anywhere still requires the certificate subject to be non-empty, so issued leaf certificates should include at least one subject RDN such as `O` or `OU` even when authorization is based on SAN values.

Example:

```
spiffe://blacks4/team1/dev/app
```

Why:

- Structured identity (team / environment / service)
- Enforced in both Vault PKI roles and AWS IAM policies
- AWS evaluates SAN fields, not `common_name`

---

## Vault Responsibilities

- Manage PKI (root / intermediate CA)
- Define PKI roles (identity boundaries)
- Configure AppRole authentication
- Issue certificates

---

## AWS Responsibilities

- Configure Roles Anywhere Trust Anchor
- Manage certificate bundles (rotation)
- Define Profiles
- Create IAM roles and policies

---

## Certificate Lifecycle

- One CA can be reused across all AWS accounts
- Trust Anchor supports **certificate bundles**

Rotation process:

1. Add new CA to bundle
2. Begin issuing new certs
3. Wait for old certs to expire
4. Remove old CA

No Trust Anchor ARN changes required.

---

## Security Model

- Vault does **not store AWS credentials**
- Vault does **not call AWS APIs**
- Authentication = certificate (identity)
- Authorization = IAM policy

---

## Notes

- AppRole secret-id generator tokens are scoped to only generate `secret_id`
- PKI roles restrict allowed SPIFFE identities
- Hub roles must align with spoke role trust policies
- Role chaining introduces a 1-hour session limit (AWS constraint)

---

## Expected Outcome

After deployment:

- Workloads authenticate to Vault using AppRole
- Vault issues short-lived certificates
- AWS Roles Anywhere exchanges certs for temporary credentials
- Workloads assume correct roles and access AWS resources

---

## Disclaimer

This repository is a **sanitized example for demonstration purposes only**.

It is not production-hardened and should be adapted to meet your organization’s security, networking, and operational requirements.

