locals {
  production_readiness = {
    rules = [
      {
        identifier = "has_owner"
        title      = "Has an owning team"
        level      = "Bronze"
        query = {
          combinator = "and"
          conditions = [
            jsonencode({
              property = "$team"
              operator = "isNotEmpty"
            }),
          ]
        }
      },
      {
        identifier = "has_readme"
        title      = "Has a README"
        level      = "Silver"
        query = {
          combinator = "and"
          conditions = [
            jsonencode({
              property = "readme"
              operator = "isNotEmpty"
            }),
          ]
        }
      },
      {
        identifier = "has_url"
        title      = "Has a repository URL"
        level      = "Gold"
        query = {
          combinator = "and"
          conditions = [
            jsonencode({
              property = "url"
              operator = "isNotEmpty"
            }),
          ]
        }
      },
    ]
  }
}
