output "scorecard_identifier" {
  description = "Configured Port scorecard identifier."
  value       = module.production_readiness_scorecard.identifier
}

output "scorecard_title" {
  description = "Configured Port scorecard title."
  value       = module.production_readiness_scorecard.title
}

output "scorecard_rules" {
  description = "Rules applied by the scorecard."
  value       = module.production_readiness_scorecard.rules
}
