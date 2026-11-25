# Optional dashboards. Off by default: create_pages = false.
#
# The page definitions are read from ../definitions/pages, the same files the Port CLI script
# applies. There is one copy. __SERVICE_BLUEPRINT__ is replaced with var.service_blueprint_identifier.

locals {
  page_ids = ["org_structure", "my_team", "management", "ownership_trail"]

  pages = {
    for id in local.page_ids : id => jsondecode(replace(
      file("${path.module}/../definitions/pages/${id}.json"),
      "__SERVICE_BLUEPRINT__",
      var.service_blueprint_identifier
    ))
  }
}

resource "port_page" "ownership" {
  for_each = { for id, page in local.pages : id => page if var.create_pages }

  identifier = each.value.identifier
  title      = each.value.title
  icon       = each.value.icon
  type       = each.value.type

  widgets      = [for widget in each.value.widgets : jsonencode(widget)]
  page_filters = [for filter in each.value.pageFilters : jsonencode(filter)]

  depends_on = [
    port_system_blueprint.team,
    port_system_blueprint.user,
    port_aggregation_properties.team_size,
    port_blueprint.service,
    port_blueprint.ownership_change,
  ]
}
