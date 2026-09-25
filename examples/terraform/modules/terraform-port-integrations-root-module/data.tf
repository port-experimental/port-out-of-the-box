locals {
  spec = jsonencode({
    integrationSpec = {
      linearApiKey = var.api_key_name
    }
  })

  config = jsonencode({
    resources = [
      {
        kind = "issue"
        selector = {
          query = "true"
        }
        port = {
          entity = {
            mappings = {
              identifier = ".identifier"
              blueprint  = "\"linearIssue\""
              title      = ".title"
              properties = {
                url      = ".url"
                status   = ".state.name"
                priority = ".priorityLabel"
              }
            }
          }
        }
      }
    ]
  })
}