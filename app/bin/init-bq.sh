#!/usr/bin/env bash
set -euo pipefail

echo "Confirm BigQuery dataset '$RECHARGE_BQ_DATASET' exists ..."
bq ls "$RECHARGE_BQ_DATASET" || {
  echo " > bq: Creating new dataset: ${RECHARGE_BQ_DATASET}"
  bq mk "$RECHARGE_BQ_DATASET"
}

tables=(
  newrelic_appdex
  newrelic_enduser
  elastic_appdex
)

views=(
  day
  month
  year
)

for table in "${tables[@]}"
do
  bq ls "$RECHARGE_BQ_DATASET" | grep -q "${table}_v${SCHEMA_VERSION}[[:space:]]\\+TABLE" || {
    echo " > bq: Creating new table: $RECHARGE_BQ_DATASET.${table}_v${SCHEMA_VERSION} ..."
    bq mk \
      --table \
      --description "Planet4 Recharge SLA data" \
      "$RECHARGE_BQ_DATASET.${table}_v${SCHEMA_VERSION}" \
      "/app/schema/schema_v${SCHEMA_VERSION}.json"
  }

  for view in "${views[@]}"
  do
    bq ls "$RECHARGE_BQ_DATASET" | grep -q "${table}_${view}_v${SCHEMA_VERSION}[[:space:]]\\+VIEW" || {
      echo " > bq: Creating view: $RECHARGE_BQ_DATASET.${table}_${view}_v${SCHEMA_VERSION} ..."

      query=$(cat <<EOF
SELECT
  *
FROM
  \`$RECHARGE_PROJECT_ID.$RECHARGE_BQ_DATASET.${table}_v${SCHEMA_VERSION}\`
WHERE
  period="${view}"
  AND \`to\` BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 1 ${view})
  AND CURRENT_DATE()
EOF
)

      echo "$query"

      bq mk \
        --use_legacy_sql=false \
        --description "Planet4 Recharge View: ${table//_/ } for the previous 1 $view" \
        --view "$query" \
        "$RECHARGE_BQ_DATASET.${table}_${view}_v${SCHEMA_VERSION}"
    }
  done
done
