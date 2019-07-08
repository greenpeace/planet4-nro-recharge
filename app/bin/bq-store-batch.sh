#!/usr/bin/env bash
# shellcheck disable=SC2086

set -euo pipefail

tables=(
  appdex
  enduser
)

mkdir -p /tmp/batch/

for t in "${tables[@]}"
do
  [[ $(find /tmp -name etl-$t-\* | wc -l) -gt 0 ]] || {
    echo "No files matching etl-$t-*.json in /tmp/ ?"
    ls -al /tmp/

    echo "Skipping ..."
    continue
  }

  ls /tmp/

  # Concatonate files
  jq -cMs 'map(.) | .[]' /tmp/etl-"$t"-*.json > "/tmp/batch/$t.json"

  # Upload to BigQuery
  bq-store-single.sh "/tmp/batch/$t.json" "newrelic_$t"
done
