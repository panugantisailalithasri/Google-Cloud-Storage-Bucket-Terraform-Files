output "bucket_name" {
  description = "Dedicated remote-backend bucket for this agent."
  value       = module.state_bucket.name
}

output "bucket_url" {
  description = "gs:// URL of the state bucket."
  value       = module.state_bucket.url
}
