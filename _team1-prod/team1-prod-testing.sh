#!/bin/bash

: <<'NOTES'
# Some process generates the secret_id token for the app teams and provides that Vault token plus the AppRole role_id:
vault token create -policy=team1-prod-approle-secretid -renewable -orphan -ttl=24h

*/
NOTES

####### AUTOMATED #######
export VAULT_ADDR="https://vault.server.com:8200"
export VAULT_NAMESPACE="admin"
export SECRET_ID_VAULT_TOKEN="TEAM1_PROD_SECRET_ID_VAULT_TOKEN_PLACEHOLDER"
export ROLE_ID="TEAM1_PROD_ROLE_ID_PLACEHOLDER"
export APPROLE_NAME="team1-prod"
export PKI_ROLE_NAME="team1-prod"
export CERT_PREFIX="team1-prod"
export TRUST_ANCHOR_ARN="arn:aws:rolesanywhere:us-east-1:1234567890:trust-anchor/5b41b87c-a9b7-4816-ae05-3b2dc27a7fb3"
export PROFILE_ARN="arn:aws:rolesanywhere:us-east-1:1234567890:profile/2c8032d2-0a0d-43bb-b733-de74cada83c8"
export ROLE_ARN="arn:aws:iam::1234567890:role/ra-hub-team1-prod"
export SPOKE_ROLE_ARN="arn:aws:iam::0987654321:role/ra-spoke-team1-prod"
export SPIFFE_URI="spiffe://example/team1/prod/app"
export ROLE_SESSION_NAME="test"

failures=0

report_success() {
  printf '%s\n\n' "$1: SUCCESS"
}

report_failure() {
  printf '%s\n\n' "$1: FAILED"
  failures=$((failures + 1))
}

report_expected_failure() {
  printf '%s\n\n' "$1: EXPECTED FAILURE"
}

# renew self (secret_id Vault token)
if curl -fsS \
  --header "X-Vault-Token: $SECRET_ID_VAULT_TOKEN" \
  --request POST \
  "$VAULT_ADDR/v1/auth/token/renew-self" >/dev/null; then
  report_success "secret_id Vault token renewed"
else
  report_failure "secret_id Vault token renewed"
fi
sleep 2

# generate new secret_id
if SECRET_ID=$(curl -fsS \
  --header "X-Vault-Token: $SECRET_ID_VAULT_TOKEN" \
  --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
  --request POST \
  "$VAULT_ADDR/v1/auth/approle/role/$APPROLE_NAME/secret-id" \
  | jq -er '.data.secret_id'); then
  report_success "New secret_id generated"
else
  SECRET_ID=""
  report_failure "New secret_id generated"
fi
sleep 2

# auth to Vault via AppRole
if VAULT_TOKEN=$(curl -fsS \
  --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
  --request POST \
  --data "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" \
  "$VAULT_ADDR/v1/auth/approle/login" \
  | jq -er '.auth.client_token'); then
  export VAULT_TOKEN
  report_success "Authenticated to Vault via AppRole"
else
  unset VAULT_TOKEN
  report_failure "Authenticated to Vault via AppRole"
fi
sleep 2

# generate Roles Anywhere PKI cert and save cert and key as local files
if curl -fsS \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
  --request POST \
  --data "{\"uri_sans\":\"$SPIFFE_URI\"}" \
  "$VAULT_ADDR/v1/pki-aws-2-int/issue/$PKI_ROLE_NAME" \
  > "$CERT_PREFIX.json" && \
  jq -er '.data.certificate' "$CERT_PREFIX.json" > "$CERT_PREFIX.pem" && \
  jq -er '.data.private_key' "$CERT_PREFIX.json" > "$CERT_PREFIX.key" && \
  jq -er '.data.issuing_ca' "$CERT_PREFIX.json" > "${CERT_PREFIX}_ca.pem"; then
  report_success "Generated Roles Anywhere PKI cert and saved cert and key as local files"
else
  report_failure "Generated Roles Anywhere PKI cert and saved cert and key as local files"
fi
sleep 2

# auth to Roles Anywhere (in the hub account) and set necessary AWS auth ENVVARs
if aws_creds=$(aws_signing_helper credential-process \
  --certificate "$CERT_PREFIX.pem" \
  --private-key "$CERT_PREFIX.key" \
  --trust-anchor-arn "$TRUST_ANCHOR_ARN" \
  --profile-arn "$PROFILE_ARN" \
  --role-arn "$ROLE_ARN" \
  | jq -er '"export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)"') && \
  eval "$aws_creds"; then
  report_success "Authenticated to Roles Anywhere and set AWS auth ENVVARs"
else
  report_failure "Authenticated to Roles Anywhere and set AWS auth ENVVARs"
fi
sleep 3

# run AWS commands as necessary while authenticated into the RA hub account (should not have any access to S3)
if aws s3 ls; then
  report_failure "aws s3 ls while authenticated to the RA hub account unexpectedly succeeded"
else
  report_expected_failure "aws s3 ls while authenticated to the RA hub account (should not have access)"
fi
sleep 3

# assume role of the spoke account and set new AWS auth ENVVARs
if spoke_creds=$(aws sts assume-role \
  --role-arn "$SPOKE_ROLE_ARN" \
  --role-session-name "$ROLE_SESSION_NAME" \
  | jq -er '"export AWS_ACCESS_KEY_ID=\(.Credentials.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.Credentials.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.Credentials.SessionToken)"') && \
  eval "$spoke_creds"; then
  report_success "Assumed role of the spoke account and set new AWS auth ENVVARs"
else
  report_failure "Assumed role of the spoke account and set new AWS auth ENVVARs"
fi

sleep 3
# run AWS commands as necessary 
if aws s3 ls; then
  report_success "aws s3 ls while authenticated to the spoke account"
else
  report_failure "Ran AWS commands"
fi

rm -f "$CERT_PREFIX.json" "$CERT_PREFIX.pem" "${CERT_PREFIX}_ca.pem" "$CERT_PREFIX.key"

if [ "$failures" -gt 0 ]; then
  printf '%s\n\n' "Script completed with $failures FAILED step(s)"
else
  printf '%s\n\n' "Script completed successfully"
fi
