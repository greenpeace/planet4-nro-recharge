#!/bin/sh
# shellcheck disable=SC1091
set -exuo pipefail

# Creates DATE_START and DATE_END variables for re-use
. ./get_dates.sh

activate-service-account.sh

make-bucket.sh

# Fetch SLA data for application on date
newrelic-get-application-sla.sh

# No file?
if [ ! -f "${RECHARGE_OUTPUT_FILE}" ]
then
  >&2 echo "Error: output file '${RECHARGE_OUTPUT_FILE}' not found"
  exit 1
fi

newrelic-upload-sla.sh
