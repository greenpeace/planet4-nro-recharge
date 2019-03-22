#!/bin/sh
# shellcheck disable=SC1091
set -euo pipefail

echo
echo "========================================================================="
echo
echo "Storing Recharge Data"
echo
echo "App:    ${NEWRELIC_APP_NAME}"
echo "Path:   ${RECHARGE_BUCKET_PATH}"
echo "Period: ${RECHARGE_PERIOD}"
echo

# Determines and exports DATE_START and DATE_END variables for re-use
. get_dates.sh

# Authenticates with GCP service account
activate-service-account.sh

# Ensures the bucket for storing data exists
make-bucket.sh

# Extract, transform, load NewRelic SLA data to BigQuery
newrelic.sh

date
echo "OK"
echo
