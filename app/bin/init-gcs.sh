#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
. /app/bin/retry.sh

init_recharge_bucket() {
  # Make bucket if it doesn't exist
  gsutil ls -p "${RECHARGE_PROJECT_ID}" "gs://${RECHARGE_BUCKET_NAME}" >/dev/null || {
    echo "Initialising WP Stateless bucket"
    echo
    echo "Project: ${RECHARGE_PROJECT_ID}"
    echo "Labels:"
    echo " - app:         planet4-nro-recharge"
    echo " - environment: production"
    echo " - component:   newrelic"
    echo "Bucket:  gs://${RECHARGE_BUCKET_NAME}"
    echo "Region:  us"

    gsutil mb -l "${RECHARGE_BUCKET_LOCATION}" -p "${RECHARGE_PROJECT_ID}" "gs://${RECHARGE_BUCKET_NAME}"
  }

  # Apply labels
  gsutil label ch \
    -l "app:planet4" \
    -l "environment:production" \
    -l "component:recharge" \
    "gs://${RECHARGE_BUCKET_NAME}"
}

init_gcs_usage_bucket() {
  # Make bucket if it doesn't exist
  gsutil ls -p "${RECHARGE_PROJECT_ID}" "gs://${USAGE_BUCKET_NAME}" >/dev/null || {
    echo "Initialising WP Stateless bucket"
    echo
    echo "Project: ${RECHARGE_PROJECT_ID}"
    echo "Labels:"
    echo " - app:         planet4-nro-recharge"
    echo " - environment: production"
    echo " - component:   usage"
    echo "Bucket:  gs://${USAGE_BUCKET_NAME}"
    echo "Region:  us"

    gsutil mb -l "${RECHARGE_BUCKET_LOCATION}" -p "${RECHARGE_PROJECT_ID}" "gs://${USAGE_BUCKET_NAME}"
  }

  # Apply lifecycle configuration
  gsutil lifecycle set lifecycle.json "gs://${USAGE_BUCKET_NAME}"

  # Apply labels
  gsutil label ch \
    -l "app:planet4" \
    -l "environment:production" \
    -l "component:usage" \
    "gs://${USAGE_BUCKET_NAME}"

  # Enable Cloud Storage WRITE permission
  gsutil acl ch -g cloud-storage-analytics@google.com:W "gs://${USAGE_BUCKET_NAME}"

  # Set default ACL of objects to private
  gsutil defacl set project-private "gs://${USAGE_BUCKET_NAME}"
}

# Retrying here because gsutil is flaky, connection resets often
retry init_recharge_bucket
retry init_gcs_usage_bucket
