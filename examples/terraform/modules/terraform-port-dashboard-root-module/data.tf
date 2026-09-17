locals {
  sample_dashboard = {
    widgets = jsonencode({
      id = "dashboardWidget"
      layout = [
        {
          height = 400
          columns = [
            {
              id   = "microserviceGuide"
              size = 12
            }
          ]
        }
      ]
      type = "dashboard-widget"
      widgets = [
        {
          title       = "Terraform managed dashboard"
          icon        = "Terraform"
          markdown    = "# This page was created using Terraform"
          type        = "markdown"
          description = ""
          id          = "microserviceGuide"
        }
      ]
    })
  }

  ocean_integrations = {
    widgets = jsonencode({
      id   = "oceanDashboardWidget"
      type = "dashboard-widget"
      layout = [
        {
          height = 400
          columns = [
            { id = "githubReposNumber", size = 4 },
            { id = "githubPrsNumber", size = 4 },
            { id = "jiraIssuesNumber", size = 4 }
          ]
        },
        {
          height = 400
          columns = [
            { id = "githubIssuesNumber", size = 6 },
            { id = "jiraProjectsNumber", size = 6 }
          ]
        },
        { height = 450, columns = [{ id = "ingestTrendChart", size = 12 }] },
        { height = 500, columns = [{ id = "integrationHealthTable", size = 12 }] }
      ]
      widgets = [
        { id = "githubReposNumber", type = "entities-number-chart", title = "GitHub Repositories", unit = "none", chartType = "countEntities", blueprint = "githubRepository", dataset = { combinator = "and", rules = [] }, func = "count" },
        { id = "githubPrsNumber", type = "entities-number-chart", title = "GitHub Pull Requests", unit = "none", chartType = "countEntities", blueprint = "githubPullRequest", dataset = { combinator = "and", rules = [] }, func = "count" },
        { id = "jiraIssuesNumber", type = "entities-number-chart", title = "Jira Issues", unit = "none", chartType = "countEntities", blueprint = "jiraIssue", dataset = { combinator = "and", rules = [] }, func = "count" },
        { id = "githubIssuesNumber", type = "entities-number-chart", title = "GitHub Issues", unit = "none", chartType = "countEntities", blueprint = "githubIssue", dataset = { combinator = "and", rules = [] }, func = "count" },
        { id = "jiraProjectsNumber", type = "entities-number-chart", title = "Jira Projects", unit = "none", chartType = "countEntities", blueprint = "jiraProject", dataset = { combinator = "and", rules = [] }, func = "count" },
        {
          id           = "ingestTrendChart"
          type         = "multi-line-chart"
          title        = "Entities ingested over time"
          xAxisTitle   = "Date"
          yAxisTitle   = "Entities created"
          timeInterval = "day"
          timeRange    = { preset = "last3Months" }
          lines = [
            { title = "GitHub Repositories", blueprint = "githubRepository", chartType = "countEntities", func = "count", measureTimeBy = "$createdAt" },
            { title = "GitHub Pull Requests", blueprint = "githubPullRequest", chartType = "countEntities", func = "count", measureTimeBy = "$createdAt" },
            { title = "Jira Issues", blueprint = "jiraIssue", chartType = "countEntities", func = "count", measureTimeBy = "$createdAt" }
          ]
        },
        { id = "integrationHealthTable", type = "table-entities-explorer", description = "Populated by the Sync Integration Health Status workflow (runs every 15 min)", title = "Integration Sync Health", blueprint = "integration", dataset = { combinator = "and", rules = [] }, displayMode = "widget" }
      ]
    })
  }
}