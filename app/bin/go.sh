#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

## Determine NewRelic application ID from name if not set
if [ -z "${NEWRELIC_APP_ID}" ] && [ -n "${NEWRELIC_APP_NAME}" ]
then
  echo "NEWRELIC_APP_ID: $NEWRELIC_APP_ID"
  echo "NEWRELIC_APP_NAME: $NEWRELIC_APP_NAME"
  NEWRELIC_APP_ID=$(newrelic-get-application-id.sh)
fi

if [ -z "$NEWRELIC_APP_ID" ]
then
  echo "NEWRELIC_APP_ID not specified, updating all sites ..."
fi

export NEWRELIC_APP_ID

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
go-newrelic.sh

echo
echo "========================================================================="
echo

# Extract, transform, load NewRelic SLA data to BigQuery
go-akamai.sh

echo "OK"
date
echo
