output "roles_anywhere_issuer_certificate" {
  value     = vault_pki_secret_backend_intermediate_set_signed.roles_anywhere.certificate
  sensitive = true
}

output "vault_pki_backend" {
  value = vault_mount.pki_intermediate.path
}

output "vault_cert_auth_backend" {
  value = vault_auth_backend.cert.path
}

output "vault_cert_auth_pki_backend" {
  value = vault_mount.pki_cert_auth_intermediate.path
}

output "team1_vm_cert_auth_role" {
  value = vault_cert_auth_backend_role.team1_vm.name
}

output "team1_vm_cert_auth_policy" {
  value = vault_policy.team1_vm_issue_certs.name
}

output "team1_vm_bootstrap_pki_role" {
  value = vault_pki_secret_backend_role.team1_vm_bootstrap.name
}

output "team1_vm_bootstrap_client_cert_path" {
  value = local_file.team1_vm_bootstrap_client_cert.filename
}

output "team1_vm_bootstrap_client_key_path" {
  value     = local_sensitive_file.team1_vm_bootstrap_client_key.filename
  sensitive = true
}

output "team1_vm_bootstrap_client_ca_path" {
  value = local_file.team1_vm_bootstrap_client_ca.filename
}
