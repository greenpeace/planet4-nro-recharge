#!/usr/bin/env bash
set -euo pipefail

# Return NewRelic application ID from Name

# Set application name from first parameter,
# fallback to NEWRELIC_APPNAME or error if unset
# Replace spaces with + characters
appname=$(tr ' ' '+' <<< "${1:-${NEWRELIC_APP_NAME}}")

response=$(curl -s -X GET "https://api.newrelic.com/v2/applications.json" \
     -H "X-Api-Key:${NEWRELIC_REST_API_KEY}" \
     -G -d "filter[name]=${appname}&exclude_links=true")

id=$(jq ".applications[].id" <<<"$response")

[ -z "$id" ] && {
  >&2 echo "ERROR: Application ID is blank in response:"
  >&2 jq . <<<"$response"
  exit 1
}

echo "$id"
