#!/usr/bin/env bash
set -euo pipefail

tables=(
  appdex
  enduser
)

mkdir -p /tmp/batch/

for t in "${tables[@]}"
do
  [[ $(find . -name "/tmp/etl-*-$t.json" | wc -l) -gt 0 ]] || continue

  # Concatonate files
  jq -cMs 'map(.) | .[]' /tmp/etl-*-"$t".json > "/tmp/batch/$t.json"

  # Upload to BigQuery
  bq-store-single.sh "/tmp/batch/$t.json" "newrelic_$t"
done
