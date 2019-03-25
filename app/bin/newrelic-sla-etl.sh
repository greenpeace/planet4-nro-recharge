#!/usr/bin/env bash
set -euo pipefail

nro="${1:-$RECHARGE_BUCKET_PATH}"
range="${2:-${RECHARGE_PERIOD}}"

input_file="${3:-$RECHARGE_OUTPUT_FILE}"

output_dir="$(dirname "$input_file")/transform"
mkdir -p "$output_dir"

echo "Converting NewRelic output to BigQuery table format ..."

# Application
output_file="$output_dir/appdex-$(basename "$input_file")"

jq -cM \
  --arg nro "$nro" \
  --arg range "$range" \
  '.metric_data
  | del(.metrics_not_found,.metrics_found)
  + { range: $range, nro: $nro, from: .from[0:-6], to: .to[0:-6] }
  + .metrics[0].timeslices[0].values
  | del(.metrics)' "$input_file" | tee "$output_file"

bq-store.sh "$output_file" newrelic_appdex

# End user
output_file="$output_dir/enduser-$(basename "$input_file")"

jq -cM \
  --arg nro "$nro" \
  --arg range "$range" \
  '.metric_data
  | del(.metrics_not_found,.metrics_found)
  + { range: $range, nro: $nro, from: .from[0:-6], to: .to[0:-6] }
  + .metrics[1].timeslices[0].values
  | del(.metrics)' "$input_file" | tee "$output_file"

bq-store.sh "$output_file" newrelic_enduser
