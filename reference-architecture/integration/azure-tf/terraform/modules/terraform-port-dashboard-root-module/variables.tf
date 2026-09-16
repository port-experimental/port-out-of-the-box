variable "identifier" {
  type        = string
  description = "Identifier for the starter dashboard."
  default     = "dashboard"
}

variable "title" {
  type        = string
  description = "Title for the starter dashboard."
  default     = "Terraform created dashboard"
}

variable "description" {
  type        = string
  description = "Optional description shared by both dashboards."
  default     = null
}

variable "locked" {
  type        = bool
  description = "Whether both dashboard pages are locked."
  default     = true
}

variable "icon" {
  type        = string
  description = "Optional Port icon shared by both dashboards."
  default     = "Terraform"
}

variable "parent" {
  type        = string
  description = "Optional parent page identifier shared by both dashboards."
  default     = null
}

variable "PORT_CLIENT_ID" {
  type        = string
  description = "Port client ID. Prefer supplying this through CI secrets."
  default     = null
  sensitive   = true
}

variable "PORT_CLIENT_SECRET" {
  type        = string
  description = "Port client secret. Prefer supplying this through CI secrets."
  default     = null
  sensitive   = true
}