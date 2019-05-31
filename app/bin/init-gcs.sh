#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
. /app/bin/retry.sh

init_recharge_bucket() {
  # Make bucket if it doesn't exist
  gsutil ls -p "${RECHARGE_PROJECT_ID}" "gs://${RECHARGE_BUCKET_NAME}" >/dev/null && return

  echo " * gcs: Initialising WP Stateless bucket"
  echo
  echo " * gcs: Project: ${RECHARGE_PROJECT_ID}"
  echo " * gcs: Labels:"
  echo " * gcs:  - app:         planet4-nro-recharge"
  echo " * gcs:  - environment: production"
  echo " * gcs:  - component:   newrelic"
  echo " * gcs: Bucket:  gs://${RECHARGE_BUCKET_NAME}"
  echo " * gcs: Region:  us"

  gsutil mb -l "${RECHARGE_BUCKET_LOCATION}" -p "${RECHARGE_PROJECT_ID}" "gs://${RECHARGE_BUCKET_NAME}"

  # Apply labels
  gsutil label ch \
    -l "app:planet4" \
    -l "environment:production" \
    -l "component:recharge" \
    "gs://${RECHARGE_BUCKET_NAME}"
}

# Retrying here because gsutil is flaky, connection resets often
echo "Initialising GCS bucket to store recharge data ..."
retry init_recharge_bucket
