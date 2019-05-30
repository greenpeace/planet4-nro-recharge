#!/usr/bin/env bash
set -euo pipefail

nro="${1:-$RECHARGE_BUCKET_PATH}"
period="${2:-${RECHARGE_PERIOD}}"

input_file="${3:-$RECHARGE_OUTPUT_FILE}"

output_dir="$(dirname "$input_file")"
mkdir -p "$output_dir"

# ============================================================================

# Application SLA data

echo "Converting NewRelic output to BigQuery table format ..."
output_file="$output_dir/enduser-$(basename "$input_file")"

# Manipulate data to match BQ schema
jq -cM \
  --arg nro "$nro" \
  --arg period "$period" \
  '.metric_data
  | del(.metrics_not_found,.metrics_found)
  + { period: $period, nro: $nro, from: .from[0:10], to: .to[0:10] }
  + .metrics[0].timeslices[0].values
  | del(.metrics)' "$input_file" | tee "$output_file"

# Perform all updates when processing is complete
if [ "$BATCH_UPLOAD" = "true" ]
then
  d=/tmp/batch/newrelic_appdex
  f="${nro}-${period}-$(jq -r '.to' "${output_file}").json"
  echo "Moving output file to $d/$f"
  mkdir -p $d
  mv "$output_file" "$d/$f"
else
  bq-store-single.sh "$output_file" newrelic_appdex
fi

# ============================================================================

# End user SLA data

output_file="$output_dir/enduser-$(basename "$input_file")"

# Manipulate data to match BQ schema
jq -cM \
  --arg nro "$nro" \
  --arg period "$period" \
  '.metric_data
  | del(.metrics_not_found,.metrics_found)
  + { period: $period, nro: $nro, from: .from[0:10], to: .to[0:10] }
  + .metrics[1].timeslices[0].values
  | del(.metrics)' "$input_file" | tee "$output_file"

# Perform all updates when processing is complete
if [ "$BATCH_UPLOAD" = "true" ]
then
  d=/tmp/batch/newrelic_enduser
  f="${nro}-${period}-$(jq -r '.to' "${output_file}").json"
  echo "Moving output file to $d/$f"
  mkdir -p $d
  mv "$output_file" "$d/$f"
else
  bq-store-single.sh "$output_file" newrelic_enduser
fi
