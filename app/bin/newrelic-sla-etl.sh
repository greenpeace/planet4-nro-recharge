#!/usr/bin/env bash
set -euo pipefail

# Expects Newrelic applixation ID as first parameter
newrelic_id="$1"

# Expects hostname/path as site unique identifier
site="$2"

endtime="$(date -d "${DATE_END} 23:59:59" +%s)"

# Confirm SLA data output file exists
sla_file="/tmp/sla-$RECHARGE_PERIOD-$endtime-$newrelic_id.json"
[ -e "$sla_file" ] || {
  >&2 echo "$newrelic_id ✗ ERROR: file not found: $sla_file"
  exit 1
}

# ============================================================================

# Application SLA data

echo "$newrelic_id - Converting NewRelic output to BigQuery table format ..."

output_file="/tmp/etl-appdex-$RECHARGE_PERIOD-$endtime-$newrelic_id.json"

# Manipulate data to match BQ schema
jq -cM \
  --arg site "$site" \
  --arg period "$RECHARGE_PERIOD" \
  '.metric_data
  | del(.metrics_not_found,.metrics_found)
  + { period: $period, site: $site, from: .from[0:10], to: .to[0:10] }
  + .metrics[0].timeslices[0].values
  | del(.metrics)' "$sla_file" > "$output_file"

# ============================================================================

# End user SLA data

output_file="/tmp/etl-enduser-$RECHARGE_PERIOD-$endtime-$newrelic_id.json"

# Manipulate data to match BQ schema
jq -cM \
  --arg site "$site" \
  --arg period "$RECHARGE_PERIOD" \
  '.metric_data
  | del(.metrics_not_found,.metrics_found)
  + { period: $period, site: $site, from: .from[0:10], to: .to[0:10] }
  + .metrics[1].timeslices[0].values
  | del(.metrics)' "$sla_file" > "$output_file"

echo "$newrelic_id ✓ Transformation complete"
