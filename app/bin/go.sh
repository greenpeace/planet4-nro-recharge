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

# Fetch SLA data for application on date
newrelic-get-application-sla.sh

# No file?
if [ ! -f "${RECHARGE_OUTPUT_FILE}" ]
then
  >&2 echo "Error: output file '${RECHARGE_OUTPUT_FILE}' not found"
  exit 1
fi

# Stores SLA data in bucket
newrelic-upload-sla.sh

date
echo "OK"
echo
