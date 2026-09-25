variable "title" {
  type        = string
  description = "Title displayed in Port for the integration."
  default     = "sample-integration"
}

variable "installation_id" {
  type        = string
  description = "Unique identifier for the integration installation in Port."
  default     = "sample-integration-prod"
}

variable "installation_app_type" {
  type        = string
  description = "The integration's app type, such as \"linear\", \"jira\" or \"github\"."
  default     = "linear"
}

variable "installation_type" {
  type        = string
  description = "How the integration is hosted."
  default     = "Saas"

  validation {
    condition     = contains(["Saas", "OnPrem"], var.installation_type)
    error_message = "installation_type must be either \"Saas\" or \"OnPrem\"."
  }
}

variable "api_key_name" {
  type        = string
  description = "Name of the credential in Port's internal credentials store holding the Linear API key. The key value itself is managed outside Terraform."
  default     = "integration-api-key"

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