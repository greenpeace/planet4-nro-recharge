#!/usr/bin/env bash
set -euo pipefail

# Expects Elastic service name as first parameter
elastic_servicename="$1"

# Expects hostname/path as site unique identifier
site="$2"

from="${DATE_START}"
to="${DATE_END}"

endtime="$(date -d "${DATE_END} 23:59:59" +%s)"

# Confirm SLA data output file exists
sla_file="/tmp/sla-$RECHARGE_PERIOD-$endtime-$elastic_servicename.json"
[ -e "$sla_file" ] || {
  >&2 echo "$elastic_servicename ✗ ERROR: file not found: $sla_file"
  exit 1
}

# ============================================================================

# Application SLA data

echo "$elastic_servicename - Converting NewRelic output to BigQuery table format ..."

output_file="/tmp/etl-appdex-$RECHARGE_PERIOD-$endtime-$elastic_servicename.json"

# Manipulate data to match BQ schema
if ! jq -cM \
  --arg site "$site" \
  --arg period "$RECHARGE_PERIOD" \
  --arg from "$from" \
  --arg to "$to" \
'
{
   from: $from,
   to: $to,
   period: $period,
   site: $site,
   score: 0,
   s: 0,
   t: 0,
   f: 0,
   count: .count,
   value: 0,
   threshold: 0,
   threshold_min: 0
}
' "$sla_file" > "$output_file"
then
  >&2 echo "$elastic_servicename ✗ ERROR reading file: $sla_file"
  >&2 echo
  >&2 cat "$elastic_servicename ✗ $sla_file"
  exit 1
fi