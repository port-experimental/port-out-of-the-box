output "workflow_id" {
  description = "Port workflow identifier."
  value       = module.incident_auto_triage_workflow.id
}

output "workflow_identifier" {
  description = "Configured Port workflow identifier."
  value       = module.incident_auto_triage_workflow.identifier
}

output "workflow_title" {
  description = "Configured Port workflow title."
  value       = module.incident_auto_triage_workflow.title
}
