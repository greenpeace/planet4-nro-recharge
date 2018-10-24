#!/bin/sh
set -ex

app_id=${1:-${NEWRELIC_APP_ID}}

## Determine NewRelic application ID from name if not set
if [ -z "${NEWRELIC_APP_ID}" ] && [ ! -z "${NEWRELIC_APP_NAME}" ]
then
  NEWRELIC_APP_ID=$(newrelic-get-application-id.sh)
  export NEWRELIC_APP_ID
fi

if [ -z "$NEWRELIC_APP_ID" ]
then
  >&2 echo "Error: NEWRELIC_APP_ID not set"
  exit 1
fi

set -u

range=${2:-"from=${DATE_START}T00:00:00+00:00&to=${DATE_END}T23:59:59+00:00"}

# https://docs.newrelic.com/docs/apm/reports/service-level-agreements/api-examples-sla-reports

json=$(curl -s -X GET "https://api.newrelic.com/v2/applications/$app_id/metrics/data.json" \
     -H "X-Api-Key:$NEWRELIC_REST_API_KEY" \
     -d "names[]=Apdex&names[]=EndUser/Apdex&$range&summarize=true")

mkdir -p /tmp

echo $json | jq
echo $json > $RECHARGE_OUTPUT_FILE
