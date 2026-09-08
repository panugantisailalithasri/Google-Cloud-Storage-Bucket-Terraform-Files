output "secret_ids" {
  description = "Map of input key to Secret Manager secret_id."
  value       = { for key, secret in google_secret_manager_secret.this : key => secret.secret_id }
}

output "secret_names" {
  description = "Map of input key to fully qualified secret names."
  value       = { for key, secret in google_secret_manager_secret.this : key => secret.name }
}
