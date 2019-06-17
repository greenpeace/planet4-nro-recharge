#!/usr/bin/env bash
set -euo pipefail

tables=(
  appdex
  enduser
)

for t in "${tables[@]}"
do
  # Concatonate files
  jq -cMs 'map(.) | .[]' /tmp/etl-*-"$t".json > "/tmp/batch/$t.json"

  # Upload to BigQuery
  bq-store-single.sh "/tmp/batch/$t.json" "newrelic_$t"
done
