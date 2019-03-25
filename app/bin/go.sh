#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

## Determine NewRelic application ID from name if not set
if [ -z "${NEWRELIC_APP_ID}" ] && [ -n "${NEWRELIC_APP_NAME}" ]
then
  NEWRELIC_APP_ID=$(newrelic-get-application-id.sh)
fi

if [ -z "$NEWRELIC_APP_ID" ]
then
  >&2 echo "Error: NEWRELIC_APP_ID not set"
  exit 1
fi

export NEWRELIC_APP_ID

echo
echo "========================================================================="
echo
echo "Storing Recharge Data"
echo
echo "App:    ${NEWRELIC_APP_NAME:-${NEWRELIC_APP_ID}}"
echo "Path:   ${RECHARGE_BUCKET_PATH}"
echo "Period: ${RECHARGE_PERIOD}"
echo

# Determines and exports DATE_START and DATE_END variables for re-use
. get_dates.sh

# Authenticates with GCP service account
activate-service-account.sh

# Ensures the bucket for storing data exists
init-gcs.sh

echo
echo "========================================================================="
echo

# Extract, transform, load NewRelic SLA data to BigQuery
go-newrelic.sh

echo
echo "========================================================================="
echo

# Extract, transform, load NewRelic SLA data to BigQuery
go-bucket.sh

echo
echo "========================================================================="
echo

# Extract, transform, load NewRelic SLA data to BigQuery
go-akamai.sh

echo "OK"
date
echo
