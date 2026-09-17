

variable "identifier" {
  description = "Unique identifier for the Port blueprint."
  type        = string
  default     = "CHANGEME"
}

variable "title" {
  description = "Display name of the Port blueprint."
  type        = string
  default     = "CHANGEME"
}

variable "description" {
  description = "Optional blueprint description."
  type        = string
  default     = null
}

variable "icon" {
  description = "Optional Port icon identifier."
  type        = string
  default     = null
}

variable "create_catalog_page" {
  description = "Create a catalog page when the blueprint is first created."
  type        = bool
  default     = null
}

variable "include_in_global_search" {
  description = "Include blueprint entities in Port global search."
  type        = bool
  default     = null
}

variable "force_delete_entities" {
  description = "Delete all associated Port entities when the blueprint is destroyed."
  type        = bool
  default     = false
}

variable "ownership" {
  description = "Blueprint ownership configuration."
  type        = any
  default     = null
}

variable "webhook_changelog_destination" {
  description = "Webhook changelog destination configuration."
  type        = any
  default     = null
}

variable "kafka_changelog_destination" {
  description = "Kafka changelog destination configuration."
  type        = any
  default     = null
}

variable "PORT_CLIENT_ID" {
  description = "Port client ID used to authenticate the provider."
  type        = string
  default     = null
  sensitive   = true
}
variable "PORT_CLIENT_SECRET" {
  description = "Port client secret used to authenticate the provider."
  type        = string
  default     = null
  sensitive   = true
}