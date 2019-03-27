#!/usr/bin/env bash
set -euo pipefail

bq ls "$RECHARGE_BQ_DATASET" >/dev/null || {
  echo " * bq: Creating new dataset: ${RECHARGE_BQ_DATASET}"
  bq mk "$RECHARGE_BQ_DATASET"
}

tables=(
  newrelic_appdex
  newrelic_enduser
)

for table in "${tables[@]}"
do
  bq ls "$RECHARGE_BQ_DATASET" | grep -q "${table}_v${SCHEMA_VERSION}[[:space:]]\+TABLE" || {
    echo " * bq: Creating new table: $RECHARGE_BQ_DATASET.${table}_v${SCHEMA_VERSION} ..."
    bq mk \
      --table \
      --description "Planet4 Recharge SLA data" \
      "$RECHARGE_BQ_DATASET.${table}_v${SCHEMA_VERSION}" \
      "/app/schema/schema_v${SCHEMA_VERSION}.json"
  }
done
