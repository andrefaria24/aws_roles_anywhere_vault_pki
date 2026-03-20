# AWS Roles Anywhere + Vault Hub/Spoke Test Environment

This repository provisions a sandbox test environment for using HashiCorp Vault
PKI with AWS Roles Anywhere in a hub-and-spoke AWS account pattern. The root
module configures Vault and the hub AWS account. Each `_team*` subfolder
configures a spoke AWS account role for a specific team/environment.

## What This Does

Root (hub) module:
- Enables Vault PKI and AppRole auth.
- Creates Vault PKI roles, Vault policies, and Vault AppRoles for:
  - `team1-dev`
  - `team1-prod`
  - `team2-dev`
- Creates a Roles Anywhere trust anchor and two Roles Anywhere profiles in the
  hub AWS account:
  - `ra-profile-team1`
  - `ra-profile-team2`
- Creates hub IAM roles that are assumed via Roles Anywhere, and then assume
  spoke roles in each team account:
  - `ra-hub-team1-dev`
  - `ra-hub-team1-prod`
  - `ra-hub-team2-dev`

Spoke modules (`_team1-dev`, `_team1-prod`, `_team2-dev`):
- Create an IAM role in the spoke account that trusts the hub role.
- Optionally attach readonly or admin permissions.
- Create a small S3 bucket to validate access.

## Apply Order

1. **Root / hub module first**
   ```bash
   terraform init
   terraform apply
   ```

2. **Then each spoke module**
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

## Testing Flow (team scripts)

Each `_team*/team*-testing.sh` script drives a full end‑to‑end test:

1. Use a **secret‑id generator Vault token** to create a new AppRole `secret_id`.
2. Authenticate to Vault via AppRole (`role_id` + `secret_id`).
3. Use the resulting Vault token to issue a PKI cert for Roles Anywhere.
4. Use `aws_signing_helper` to get AWS credentials via Roles Anywhere.
5. Assume the spoke role in the team account.
6. Run AWS commands (e.g., `aws s3 ls`).

Current team-to-resource mapping:

- `_team1-dev/team1-dev-testing.sh`
  - AppRole: `team1-dev`
  - PKI role: `team1-dev`
  - Roles Anywhere profile: `ra-profile-team1`
  - Hub IAM role: `ra-hub-team1-dev`
  - SPIFFE URI pattern: `spiffe://blacks4/team1/dev/*`
- `_team1-prod/team1-prod-testing.sh`
  - AppRole: `team1-prod`
  - PKI role: `team1-prod`
  - Roles Anywhere profile: `ra-profile-team1`
  - Hub IAM role: `ra-hub-team1-prod`
  - SPIFFE URI pattern: `spiffe://blacks4/team1/prod/*`
- `_team2-dev/team2-dev-testing.sh`
  - AppRole: `team2-dev`
  - PKI role: `team2-dev`
  - Roles Anywhere profile: `ra-profile-team2`
  - Hub IAM role: `ra-hub-team2-dev`
  - SPIFFE URI pattern: `spiffe://blacks4/team2/dev/*`

### Update Script Variables

After all Terraform code has been applied, **edit the variables** at the top of
each team testing script:

- `VAULT_ADDR`
- `VAULT_NAMESPACE`
- `SECRET_ID_VAULT_TOKEN`
- `ROLE_ID`
- `TRUST_ANCHOR_ARN`
- `PROFILE_ARN`
- `ROLE_ARN`
- `SPOKE_ROLE_ARN`
- `SPIFFE_URI`
- `APPROLE_NAME`
- `PKI_ROLE_NAME`
- `CERT_PREFIX`

The scripts now intentionally ship with placeholder values for:

- `SECRET_ID_VAULT_TOKEN`
- `ROLE_ID`

Those must be replaced after Terraform is applied and after you create the
appropriate secret-id generator token.

### Generating the Secret‑ID Generator Token

From an admin account, create a token that **only** allows generating AppRole
`secret_id` values for the team:

```bash
vault token create -policy=team1-dev-approle-secretid -renewable -orphan -ttl=24h
vault token create -policy=team1-prod-approle-secretid -renewable -orphan -ttl=24h
vault token create -policy=team2-dev-approle-secretid -renewable -orphan -ttl=2h
```

That token value is used as `SECRET_ID_VAULT_TOKEN` in the team test script.

The corresponding AppRole `role_id` values are exposed by the root module
outputs:

- `team1-dev-approle-role-id`
- `team1-prod-approle-role-id`
- `team2-dev-approle-role-id`

### What the Token Permits

The `SECRET_ID_VAULT_TOKEN` **cannot issue PKI certs**. It can only create a
`secret_id` for the team’s AppRole. The AppRole login token then has the
team’s PKI policy and can issue the matching Roles Anywhere certificate:

- `team1-dev-ra-policy` can issue `pki-aws-2-int/issue/team1-dev`
- `team1-prod-ra-policy` can issue `pki-aws-2-int/issue/team1-prod`
- `team2-dev-ra-policy` can issue `pki-aws-2-int/issue/team2-dev`

## Notes

- The hub policy must reference the exact spoke role names that exist in each
  spoke account. Keep `spoke_role_name` values in the spoke stacks aligned with
  the root variables:
  - `team1_dev_spoke_role_name`
  - `team1_prod_spoke_role_name`
  - `team2_dev_spoke_role_name`

- Team 1 is split by environment all the way through the stack:
  - Vault PKI role names
  - Vault AppRole names
  - Vault secret-id generator policies
  - Roles Anywhere hub IAM roles
  - SPIFFE URI prefixes

- Valid SPIFFE examples for the current configuration:
  - `spiffe://blacks4/team1/dev/app`
  - `spiffe://blacks4/team1/prod/app`
  - `spiffe://blacks4/team2/dev/app`

- Default AppRole token TTLs and secret_id TTLs are set to 15 minutes.

## Expected Outcome

Once configured and applied:
- Teams can generate short‑lived AppRole `secret_id` values using their
  `SECRET_ID_VAULT_TOKEN`.
- Teams can authenticate to Vault via AppRole and issue short‑lived certs.
- Roles Anywhere can assume the correct environment-specific hub role, which
  then assumes the matching spoke role.
- AWS API calls work using the assumed spoke role (e.g., `aws s3 ls`).
