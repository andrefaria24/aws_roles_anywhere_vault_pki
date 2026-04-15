# Hello World App With VSO And IAM Roles Anywhere

This directory contains a minimal Kubernetes workload that:

- uses the Vault Secrets Operator (VSO) to request an X.509 client certificate from Vault PKI
- mounts that certificate into the pod as a Kubernetes Secret
- runs `aws_signing_helper serve` as a sidecar
- lets the app container call AWS with IAM Roles Anywhere credentials through the local IMDS-compatible endpoint
- authenticates VSO to Vault with the Vault `jwt` auth method backed by Kubernetes service account tokens

The example is aligned to the Terraform in this repository:

- Vault PKI mount: `pki-aws-int`
- Vault PKI role: `team1`
- SPIFFE URI SAN: `spiffe://example/Team1/App1/hello-world`
- Example IAM role name: `HCPVaultAssumeRoleForTeam1App1`

## Layout

- `app/`: tiny Python HTTP app that returns STS caller identity and, when allowed, S3 bucket names
- `aws-signing-helper/`: container image for the AWS IAM Roles Anywhere helper
- `.env.example`: template for all environment-specific values consumed by Kustomize
- `scripts/ExportKubernetesJwtValidationPublicKeys.ps1`: exports the cluster's service-account signing keys as PEM for Vault JWT auth
- `scripts/ConfigureVaultForVsoJwt.ps1`: configures the Vault JWT auth mount and role that VSO will use
- `kustomization.yaml`: deployable manifest set for the demo namespace

## Prerequisites

1. Apply the Vault and AWS Terraform stacks in this repository.
2. Install VSO in the cluster, including its CRDs.
3. Have `kubectl` access to the Kubernetes cluster once during setup so you can read the issuer metadata and export the JWT validation public keys.
4. Build and push the two container images in this directory.

Install VSO with Helm:

```powershell
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install --version 0.10.0 `
  --create-namespace `
  --namespace vault-secrets-operator `
  vault-secrets-operator `
  hashicorp/vault-secrets-operator
```

Important:

- Run `helm` and `kubectl` from a shell that already has working cluster access.
- Avoid `sudo kubectl` and `sudo helm` unless you intentionally preserve the same kubeconfig, because `sudo` often changes `HOME` and breaks access to `~/.kube/config`.
- If Helm reports `Get "http://localhost:8080/version": connect: connection refused`, it usually means no kubeconfig was loaded in that shell.
- This example now uses Vault `jwt` auth with `jwt_validation_pubkeys`. That avoids the Kubernetes `TokenReview` requirement and is the path that works when a public HCP Vault cluster cannot reach a local WSL `k3s` API endpoint.
- If the Kubernetes service-account signing key rotates, you must export the public keys again and update the Vault JWT auth configuration.

Verify the CRDs exist before deploying this demo:

```powershell
kubectl get crd vaultauths.secrets.hashicorp.com
kubectl get crd vaultconnections.secrets.hashicorp.com
kubectl get crd vaultpkisecrets.secrets.hashicorp.com
```

If any of those CRDs are missing, the demo manifests in this directory will fail with `no matches for kind`.

Example image builds:

```powershell
docker build -t <registry>/roles-anywhere-hello-world:0.1.0 .\k8s\roles-anywhere-hello-world\app
docker build -t <registry>/aws-signing-helper:1.8.0 .\k8s\roles-anywhere-hello-world\aws-signing-helper
docker push <registry>/roles-anywhere-hello-world:0.1.0
docker push <registry>/aws-signing-helper:1.8.0
```

## Configure Vault

The AWS Terraform stack already creates the PKI role and the policy for `Team1`. VSO still needs a Vault JWT auth role that maps the pod's Kubernetes service account token claims to that policy.

First, export the Kubernetes service-account signing public keys in PEM format. Run this from a shell where `kubectl` already talks to the target cluster:

```powershell
.\k8s\roles-anywhere-hello-world\scripts\ExportKubernetesJwtValidationPublicKeys.ps1 `
  -OutputPath .\jwt_validation_pubkeys.pem
```

The script prints the issuer URL. You can also query it directly:

```powershell
kubectl get --raw /.well-known/openid-configuration
```

Then configure Vault JWT auth:

```powershell
.\k8s\roles-anywhere-hello-world\scripts\ConfigureVaultForVsoJwt.ps1 `
  -VaultAddr https://<vault-host>:8200 `
  -VaultToken <vault-token> `
  -JwtValidationPublicKeysPath .\jwt_validation_pubkeys.pem `
  -BoundIssuer https://kubernetes.default.svc.cluster.local
```

If `kubectl` in the same shell already points at the target cluster, `-BoundIssuer` is optional because the script can read the issuer from `/.well-known/openid-configuration`.

This script:

- enables the Vault auth mount at `auth/jwt` if needed
- configures `auth/jwt/config` with `jwt_validation_pubkeys` and `bound_issuer`
- creates a JWT role bound to:
  - `aud = vault`
  - `sub = system:serviceaccount:roles-anywhere-demo:roles-anywhere-demo`
- attaches the existing Vault policy `team1-iam-roles-anywhere-issue-certs`

## Update The Example Values

This example now reads its environment-specific values from `./.env` through Kustomize.

Create the file from the template:

```powershell
Copy-Item .\k8s\roles-anywhere-hello-world\.env.example .\k8s\roles-anywhere-hello-world\.env
```

Then edit `./k8s/roles-anywhere-hello-world/.env` and set:

- `APP_IMAGE`
- `AWS_SIGNING_HELPER_IMAGE`
- `VAULT_ADDR`
- `AWS_TRUST_ANCHOR_ARN`
- `AWS_PROFILE_ARN`
- `AWS_ROLE_ARN`

The same `.env` file also drives:

- the hello-world message and AWS region
- the Vault namespace, JWT auth mount, auth role, and audience
- the Vault PKI mount, PKI role, and requested SPIFFE URI

If Vault uses a private CA, keep using `vault-server-ca-secret.example.yaml` separately. That secret is intentionally not sourced from `.env`.

Important:

- The PKI role name created by Terraform is lower-case team name, so `Team1` becomes `team1`.
- The URI SAN must stay inside the AWS trust policy pattern. For `Team1` and `App1`, the allowed pattern is `spiffe://example/Team1/App1/*`.
- The current Terraform PKI role only constrains URI SANs and does not allow an arbitrary certificate common name, so this example omits `commonName` from `vault-pki-secret.yaml`.
- If you use Vault Enterprise namespaces or HCP Vault Dedicated, set the correct Vault namespace in `.env` as `VAULT_NAMESPACE`.
- For a public HCP Vault endpoint, do not set `caCertSecretRef` in `vault-connection.yaml`. VSO should use the system trust store. Only set `caCertSecretRef` when the Vault HTTPS certificate chains to a private CA that the cluster does not already trust.
- The `vault-auth.yaml` in this example uses `method: jwt` and asks VSO to mint a short-lived service account token with the audience configured in `.env`.

Validate the rendered manifests before applying them:

```powershell
kubectl kustomize .\k8s\roles-anywhere-hello-world
```

## Deploy

If Vault uses a private CA, apply the CA secret first:

```powershell
kubectl apply -f .\k8s\roles-anywhere-hello-world\vault-server-ca-secret.example.yaml
```

Then deploy the demo:

```powershell
kubectl apply -k .\k8s\roles-anywhere-hello-world
```

## Verify

Wait for VSO to issue the certificate and for the deployment to become ready:

```powershell
kubectl get vaultpkisecret -n roles-anywhere-demo
kubectl get secret roles-anywhere-client-cert -n roles-anywhere-demo
kubectl rollout status deployment/roles-anywhere-hello-world -n roles-anywhere-demo
```

Port-forward the service and call the app:

```powershell
kubectl port-forward -n roles-anywhere-demo svc/roles-anywhere-hello-world 8080:80
curl http://127.0.0.1:8080/
```

You should see:

- a hello-world message
- the STS caller identity for the IAM role selected through IAM Roles Anywhere
- S3 bucket names if the role also has `s3:ListAllMyBuckets`

## Notes

- The helper sidecar uses `aws_signing_helper serve`, so the application consumes credentials from `http://127.0.0.1:9911`.
- The VSO-generated TLS secret is mounted read-only into the helper container.
- The app itself never receives a static AWS access key.
- Vault JWT auth validates the service account token cryptographically. Unlike Vault Kubernetes auth, it does not call Kubernetes `TokenReview`, so revoked tokens remain valid until they expire. Use short token TTLs and a narrow audience.

## Cleanup

Use this section to remove the demo from Kubernetes, Vault, and AWS.

Important:

- The commands below assume this demo was deployed into a dedicated namespace, Vault auth role, and Terraform workspace.
- If your Vault auth mount or Terraform stacks are shared with anything else, remove only the specific demo objects instead of destroying the whole stack.

### Kubernetes

Delete the demo resources:

```powershell
kubectl delete -k .\k8s\roles-anywhere-hello-world --ignore-not-found
```

If the namespace still exists, remove it explicitly:

```powershell
kubectl delete namespace roles-anywhere-demo --ignore-not-found
```

If you installed VSO only for this demo, uninstall it too:

```powershell
helm uninstall vault-secrets-operator -n vault-secrets-operator
kubectl delete namespace vault-secrets-operator --ignore-not-found
```

### Vault

If you configured the JWT auth mount and role specifically for this demo with `ConfigureVaultForVsoJwt.ps1`, remove the role:

```powershell
$headers = @{
  "X-Vault-Token" = "<vault-token>"
  "X-Vault-Namespace" = "admin"
}

Invoke-RestMethod `
  -Method Delete `
  -Uri "https://<vault-host>:8200/v1/auth/jwt/role/roles-anywhere-demo" `
  -Headers $headers
```

If the `auth/jwt` mount was created only for this demo and is not shared, disable it:

```powershell
Invoke-RestMethod `
  -Method Delete `
  -Uri "https://<vault-host>:8200/v1/sys/auth/jwt" `
  -Headers $headers
```

Do not disable `auth/jwt` if other workloads use it.

### AWS And Terraform-Managed Vault PKI

The AWS stack in this repository creates:

- IAM Roles Anywhere trust anchor
- IAM Roles Anywhere profile
- IAM roles
- supporting Vault PKI roles and Vault policies

Destroy that stack from [`iac/aws`](C:/Dev/aws_roles_anywhere_vault_pki/iac/aws/README.md):

```powershell
cd .\iac\aws
terraform destroy
```

The Vault stack in this repository creates:

- root and intermediate PKI mounts
- root and intermediate certificates

Destroy that stack from [`iac/vault`](C:/Dev/aws_roles_anywhere_vault_pki/iac/vault/README.md) if you want to remove the PKI hierarchy as well:

```powershell
cd .\iac\vault
terraform destroy
```

If you used `terraform.tfvars` or environment variables during apply, use the same inputs during destroy.
