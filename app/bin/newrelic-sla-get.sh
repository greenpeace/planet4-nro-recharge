#!/usr/bin/env bash
set -eo pipefail

app_id=${1:-${NEWRELIC_APP_ID}}

set -u

range=${2:-"from=${DATE_START}T00:00:00+00:00Z&to=${DATE_END}T23:59:59+00:00Z"}

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

# Echo output for logs
jq -M . < "$RECHARGE_OUTPUT_FILE"
