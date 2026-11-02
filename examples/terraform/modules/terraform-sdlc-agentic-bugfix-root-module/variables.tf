variable "jira_cloud_id" {
  description = "Atlassian cloud ID of the Jira site used for issue creation and comments."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f-]{36}$", var.jira_cloud_id))
    error_message = "jira_cloud_id must be an Atlassian cloud ID (UUID)."
  }
}

variable "category" {
  description = "Default category for workflows that do not set an explicit override."
  type        = string
  default     = "Engineering"

  validation {
    condition     = length(var.category) <= 40
    error_message = "Workflow category must be 40 characters or fewer."
  }
}
