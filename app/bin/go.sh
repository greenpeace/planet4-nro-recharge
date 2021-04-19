#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# Authenticates with GCP service account
echo "Activating service account ..."
activate-service-account.sh

# Determine the date range we want to extract data for
. /app/bin/get_dates.sh

# Initialise bucket and dataset, unless FAST_INIT is set to 'true'
[[ "${FAST_INIT}" = true ]] || {
  # Ensures the bucket for storing data exists
  init-gcs.sh

  # Ensures the bucket for storing data exists
  init-bq.sh
}

echo
echo "========================================================================="
echo
echo "Storing Recharge Data"
echo
echo "App:    ${NEWRELIC_APP_NAME:-${NEWRELIC_APP_ID:-**all**}}"
echo "Period: ${RECHARGE_PERIOD}"
echo
echo "========================================================================="
echo


# Extract, transform, load NewRelic SLA data to BigQuery
go-elastic.sh

bq-store-batch-elastic.sh

# Synchronise local changes with GCS bucket
gsutil -m rsync -d -r /tmp/bucket "gs://${RECHARGE_BUCKET_NAME}"

echo "OK"
date
echo
