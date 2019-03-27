#!/usr/bin/env bash
set -euo pipefail

app_id=${1:-${NEWRELIC_APP_ID}}
range=${2:-"from=${DATE_START}T00:00:00+00:00Z&to=${DATE_END}T23:59:59+00:00Z"}

now=$(date -d 'now' +%s)
end=$(date -d "${DATE_END} 23:59:59" +%s)

[[ "$end" -ge "$now" ]] && {
  >&2 echo "WARNING: End date is in the future. Skipping ..."
  exit 0
}

# https://docs.newrelic.com/docs/apm/reports/service-level-agreements/api-examples-sla-reports
mkdir -p /tmp

echo
echo "Fetching NewRelic SLA data ..."
echo
echo "App:    https://rpm.newrelic.com/accounts/301342/applications/$app_id"
echo "Dates:  $range"
echo

curl -s -X GET "https://api.newrelic.com/v2/applications/$app_id/metrics/data.json" \
     -H "X-Api-Key:$NEWRELIC_REST_API_KEY" \
     -d "names[]=Apdex&names[]=EndUser/Apdex&$range&summarize=true" -o "$RECHARGE_OUTPUT_FILE"

jq -e '.error' "$RECHARGE_OUTPUT_FILE" > /dev/null && {
  >&2 echo "ERROR: NewRelic API said: $(jq '.error.title' "$RECHARGE_OUTPUT_FILE")"
  echo
  exit 1
}

# Echo output for logs
jq -M . < "$RECHARGE_OUTPUT_FILE"
