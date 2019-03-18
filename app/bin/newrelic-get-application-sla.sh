#!/bin/sh
set -euo pipefail

app_id=${1:-${NEWRELIC_APP_ID}}

## Determine NewRelic application ID from name if not set
if [ -z "${NEWRELIC_APP_ID}" ] && [ -n "${NEWRELIC_APP_NAME}" ]
then
  app_id=$(newrelic-get-application-id.sh)
fi

if [ -z "$app_id" ]
then
  >&2 echo "Error: NEWRELIC_APP_ID not set"
  exit 1
fi

set -u

range=${2:-"from=${DATE_START}Z00:00:00+00:00&to=${DATE_END}Z23:59:59+00:00"}

# https://docs.newrelic.com/docs/apm/reports/service-level-agreements/api-examples-sla-reports
mkdir -p /tmp

echo
echo "Fetching NewRelic SLA data ..."
echo
echo "App:    https://rpm.newrelic.com/accounts/301342/applications/$app_id"
echo "Period: ${RECHARGE_PERIOD}"
echo "Dates:  $range"
echo

curl -s -X GET "https://api.newrelic.com/v2/applications/$app_id/metrics/data.json" \
     -H "X-Api-Key:$NEWRELIC_REST_API_KEY" \
     -d "names[]=Apdex&names[]=EndUser/Apdex&$range&summarize=true" -o "$RECHARGE_OUTPUT_FILE"

jq . < "$RECHARGE_OUTPUT_FILE"
