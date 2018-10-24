#!/bin/sh
set -euo pipefail

echo
echo "========================================================================="
echo
echo "Initialising WP Stateless bucket"
echo
echo "Project: ${RECHARGE_PROJECT_ID}"
echo "Labels:"
echo " - app:         planet4-nro-recharge"
echo " - environment: production"
echo "Bucket:  gs://${RECHARGE_BUCKET_NAME}"
echo "Region:  us"
echo

init_bucket() {
  # Make bucket if it doesn't exist
  gsutil ls -p "${RECHARGE_PROJECT_ID}" "gs://${RECHARGE_BUCKET_NAME}" \
  || gsutil mb -l "${RECHARGE_BUCKET_LOCATION}" -p "${RECHARGE_PROJECT_ID}" \
    "gs://${RECHARGE_BUCKET_NAME}"

  # Apply labels
  gsutil label ch \
    -l "app:planet4" \
    -l "environment:production" \
    -l "component:recharge" \
    "gs://${RECHARGE_BUCKET_NAME}"

  okay=1
}

# Retrying here because gsutil is flaky, connection resets often
okay=0
i=0
retry=3

while [ $okay -ne 1 ]
do
  init_bucket

  [ $okay -eq 1 ] && exit

  i=$(($i+1))
  [ $i -gt $retry ] && break
  echo "Retry: $i/$retry"
done

echo "FAILED initialising bucket gs://${RECHARGE_BUCKET_NAME}" && exit 1
