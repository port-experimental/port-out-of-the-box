variable "port_client_id" {
  description = "Port client ID used to authenticate the Terraform provider. Prefer the PORT_CLIENT_ID environment variable."
  type        = string
  sensitive   = true
  default     = null
}

variable "port_client_secret" {
  description = "Port client secret used to authenticate the Terraform provider. Prefer the PORT_CLIENT_SECRET environment variable."
  type        = string
  sensitive   = true
  default     = null
}

variable "port_base_url" {
  description = "Port API base URL, without /v1. Leave null for the provider default. Set it to match your organization region, for example https://api.us.getport.io for a US organization."
  type        = string
  default     = null
}

variable "service_blueprint_identifier" {
  description = "Identifier of the blueprint that represents your services. Swarms are linked to entities of this blueprint."
  type        = string
  default     = "service"
}

variable "create_service_blueprint" {
  description = <<-EOT
    Create a minimal service blueprint. Only for new or sandbox organizations.
    If you already have a service blueprint, leave this false and add the pending_swarm relation,
    the pending_swarm_parent mirror property and Direct ownership to it yourself (see the README).
  EOT
  type        = bool
  default     = false
}

variable "workflow_requestor_roles" {
  description = "Port roles that can run the swarm forms."
  type        = list(string)
  default     = ["Admin"]
}

variable "workflow_requestor_teams" {
  description = "Identifiers of Port teams that can run the swarm forms, in addition to the roles above. The teams must already exist."
  type        = list(string)
  default     = []
}

variable "create_pages" {
  description = "Create the four dashboard pages: Org Structure, My Team, Management and Ownership trail."
  type        = bool
  default     = false
}
