output "workflows" {
  description = "Identifiers of the workflows created by this pattern."
  value = [
    port_workflow.create_swarm.identifier,
    port_workflow.add_user_to_swarm.identifier,
    port_workflow.apply_pending_swarm.identifier,
    port_workflow.add_swarm_to_service.identifier,
    port_workflow.apply_pending_owner.identifier,
    port_workflow.log_service_owner_change.identifier,
    port_workflow.log_user_team_change.identifier,
  ]
}

output "pages" {
  description = "Identifiers of the dashboard pages created by this pattern. Empty unless create_pages is true."
  value       = [for page in port_page.ownership : page.identifier]
}
