variable "port_client_id" {
  description = "Port client ID used to authenticate the Terraform provider."
  type        = string
  sensitive   = true
  default     = null
}

variable "port_client_secret" {
  description = "Port client secret used to authenticate the Terraform provider."
  type        = string
  sensitive   = true
  default     = null
}

variable "category" {
  description = "The category for the workflow."
  type        = string
  default     = "Terraform"
}
