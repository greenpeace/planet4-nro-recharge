#!/usr/bin/env bash
set -euo pipefail

app_id=${1:-${NEWRELIC_APP_ID}}

re='^[0-9]+$'
if ! [[ $app_id =~ $re ]]
then
   >&2 echo "ERROR: NEWRELIC_APP_ID is not a number - $app_id"
   exit 1
fi

range=${2:-"from=${DATE_START}T00:00:00+00:00Z&to=${DATE_END}T23:59:59+00:00Z"}

now=$(date -d 'now' +%s)
end=$(date -d "${DATE_END} 23:59:59" +%s)

[[ $end -ge "$now" ]] && {
  >&2 echo "WARNING: End date is in the future. Skipping ..."
  exit 0
}

# https://docs.newrelic.com/docs/apm/reports/service-level-agreements/api-examples-sla-reports
mkdir -p /tmp

echo "$app_id - Fetching NewRelic SLA data ..."
echo "$app_id - App:    https://rpm.newrelic.com/accounts/301342/applications/$app_id"
echo "$app_id - Dates:  $range"

outfile="/tmp/sla-$RECHARGE_PERIOD-${end}-${app_id}.json"

curl -s -X GET "https://api.newrelic.com/v2/applications/$app_id/metrics/data.json" \
     -H "X-Api-Key:$NEWRELIC_REST_API_KEY" \
     -d "names[]=Apdex&names[]=EndUser/Apdex&$range&summarize=true" -o "$outfile"

jq -e '.error' "$outfile" > /dev/null && {
  >&2 echo "$app_id ✗ ERROR: NewRelic API said: $(jq '.error.title' "$outfile")"
  echo
  exit 1
}

# Echo output for logs
# jq -M . < "/tmp/sla-$app_id.json"

>&2 echo "$app_id ✓ Recharge data gathered successfully"
