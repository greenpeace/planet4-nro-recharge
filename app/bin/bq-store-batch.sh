#!/usr/bin/env bash
set -euo pipefail

tables=(
  newrelic_appdex
  newrelic_enduser
)

for t in "${tables[@]}"
do
  # Concatonate files
  jq -cMs 'map(.)' /tmp/batch/"$t"/*.json > "/tmp/batch/$t.json"

  # Convert to NLD JSON
  jq -c '.[]' "/tmp/batch/$t.json" > "/tmp/batch/$t-nld.json"

  # Upload to BigQuery
  bq-store-single.sh "/tmp/batch/$t-nld.json" "$t"
done
