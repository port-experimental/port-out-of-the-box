output "id" {
  description = "Port's internal identifier for the integration resource."
  value       = module.sample-integration.id
}

output "title" {
  description = "Title displayed in Port."
  value       = module.sample-integration.title
}

output "installation_id" {
  description = "Installation identifier of the integration."
  value       = module.sample-integration.installation_id
}
