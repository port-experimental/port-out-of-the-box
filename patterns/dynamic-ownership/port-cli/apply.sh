#!/usr/bin/env bash
#
# Applies the dynamic ownership pattern to a Port organization using the Port CLI.
#
# It is safe to run more than once. Blueprints are merged (existing properties,
# relations and ownership settings are kept), workflows and pages are upserted.
#
# Usage:
#   ./apply.sh                 apply everything
#   ./apply.sh --dry-run       show what would be applied, change nothing
#   ./apply.sh --with-pages    also create the four dashboard pages
#
# Configuration (environment variables):
#   PORT_CLIENT_ID, PORT_CLIENT_SECRET   required
#   PORT_API_URL                         default https://api.port.io/v1. Use https://api.us.port.io/v1 for a US organization
#   SERVICE_BLUEPRINT                    blueprint that represents your services. Default: service
#   CREATE_SERVICE_BLUEPRINT             true to create SERVICE_BLUEPRINT when it does not exist. Default: false
#   REQUESTOR_TEAMS                      comma separated Port team identifiers allowed to run the forms,
#                                        in addition to the Admin role. Default: none

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=false
WITH_PAGES=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --with-pages) WITH_PAGES=true ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

: "${PORT_CLIENT_ID:?PORT_CLIENT_ID is not set}"
: "${PORT_CLIENT_SECRET:?PORT_CLIENT_SECRET is not set}"
export PORT_API_URL="${PORT_API_URL:-https://api.port.io/v1}"
SERVICE_BLUEPRINT="${SERVICE_BLUEPRINT:-service}"
CREATE_SERVICE_BLUEPRINT="${CREATE_SERVICE_BLUEPRINT:-false}"
REQUESTOR_TEAMS="${REQUESTOR_TEAMS:-}"

for tool in port jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool" >&2; exit 1; }
done

if ! [[ "$SERVICE_BLUEPRINT" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "SERVICE_BLUEPRINT must contain only letters, digits, - and _" >&2
  exit 1
fi

# The CLI reads PORT_CLIENT_ID, PORT_CLIENT_SECRET and PORT_API_URL from the environment.
# --no-env-file stops it from also loading .env files from the current directory.
api() { port api call "$@" --no-env-file; }

# Print a definition file with the placeholders replaced.
render() { sed "s/__SERVICE_BLUEPRINT__/${SERVICE_BLUEPRINT}/g" "$1"; }

exists() { api "$1" -q >/dev/null 2>&1; }

say() { printf '%s\n' "$*"; }

READONLY_KEYS='["createdAt","updatedAt","createdBy","updatedBy"]'

# Merge the additions in $2 into blueprint $1 and write the result.
merge_blueprint() {
  local id="$1" additions="$2" current body
  current="$(api "/blueprints/${id}" --unwrap blueprint)"
  body="$(jq --argjson ro "$READONLY_KEYS" --slurpfile add <(render "$additions") '
      . as $cur
      | ($add[0]) as $a
      | $cur
      | del(.[$ro[]])
      | .schema.properties      = ((.schema.properties // {})      + (($a.schema // {}).properties // {}))
      | .relations              = ((.relations // {})              + ($a.relations // {}))
      | .mirrorProperties       = ((.mirrorProperties // {})       + ($a.mirrorProperties // {}))
      | .aggregationProperties  = ((.aggregationProperties // {})  + ($a.aggregationProperties // {}))
      | if ($a.ownership != null and .ownership == null) then .ownership = $a.ownership else . end
    ' <<<"$current")"
  if $DRY_RUN; then
    say "  would update blueprint ${id}: add $(jq -r '[((.schema // {}).properties // {} | keys[]), (.relations // {} | keys[]), (.mirrorProperties // {} | keys[]), (.aggregationProperties // {} | keys[])] | join(", ")' <(render "$additions"))"
  else
    api "/blueprints/${id}" -X PUT --data "$body" >/dev/null
    say "  updated blueprint ${id}"
  fi
}

create_blueprint() {
  local id="$1" file="$2"
  if $DRY_RUN; then say "  would create blueprint ${id}"; return; fi
  api "/blueprints" -X POST --data "$(render "$file")" >/dev/null
  say "  created blueprint ${id}"
}

put_blueprint() {
  local id="$1" file="$2"
  if exists "/blueprints/${id}"; then
    if $DRY_RUN; then say "  would update blueprint ${id}"; return; fi
    api "/blueprints/${id}" -X PUT --data "$(render "$file")" >/dev/null
    say "  updated blueprint ${id}"
  else
    create_blueprint "$id" "$file"
  fi
}

upsert_workflow() {
  local file="$1" id body
  id="$(jq -r .identifier "$file")"
  body="$(render "$file" | jq --arg teams "$REQUESTOR_TEAMS" '
      ($teams | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))) as $t
      | (.nodes[] | select(.config.type == "SELF_SERVE_TRIGGER") | .config.permissions.teams) = $t')"
  if $DRY_RUN; then
    say "  would $(exists "/workflows/${id}" && echo update || echo create) workflow ${id}"
  elif exists "/workflows/${id}"; then
    api "/workflows/${id}" -X PUT --data "$body" >/dev/null
    say "  updated workflow ${id}"
  else
    api "/workflows" -X POST --data "$body" >/dev/null
    say "  created workflow ${id}"
  fi
}

upsert_page() {
  local file="$1" id body
  id="$(jq -r .identifier "$file")"
  body="$(render "$file")"
  if $DRY_RUN; then
    say "  would $(exists "/pages/${id}" && echo update || echo create) page ${id}"
  elif exists "/pages/${id}"; then
    api "/pages/${id}" -X PUT --data "$body" >/dev/null
    say "  updated page ${id}"
  else
    api "/pages" -X POST --data "$body" >/dev/null
    say "  created page ${id}"
  fi
}

say "Port API: ${PORT_API_URL}"
say "Service blueprint: ${SERVICE_BLUEPRINT}"
$DRY_RUN && say "Dry run: nothing will be changed"

say ""
say "1. Blueprints"
# _team must be extended before the workflows and pages that reference it.
merge_blueprint "_team" "$DIR/blueprints/team.json"
merge_blueprint "_user" "$DIR/blueprints/user.json"
put_blueprint "ownership_change" "$DIR/blueprints/ownership_change.json"

if exists "/blueprints/${SERVICE_BLUEPRINT}"; then
  merge_blueprint "$SERVICE_BLUEPRINT" "$DIR/blueprints/service.additions.json"
elif [ "$CREATE_SERVICE_BLUEPRINT" = "true" ]; then
  # Greenfield: start from the minimal blueprint, then add the pattern's relation, mirror and ownership.
  create_blueprint "$SERVICE_BLUEPRINT" "$DIR/blueprints/service.minimal.json"
  if ! $DRY_RUN; then merge_blueprint "$SERVICE_BLUEPRINT" "$DIR/blueprints/service.additions.json"; fi
else
  say "Blueprint '${SERVICE_BLUEPRINT}' does not exist. Set SERVICE_BLUEPRINT to your service blueprint, or CREATE_SERVICE_BLUEPRINT=true to create it." >&2
  exit 1
fi

say ""
say "2. Workflows"
for f in create_swarm add_user_to_swarm apply_pending_swarm add_swarm_to_service apply_pending_owner log_service_owner_change log_user_team_change; do
  upsert_workflow "$DIR/workflows/${f}.json"
done

if $WITH_PAGES; then
  say ""
  say "3. Pages"
  for f in org_structure my_team management ownership_trail; do
    upsert_page "$DIR/pages/${f}.json"
  done
fi

say ""
say "Done."
