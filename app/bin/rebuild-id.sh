#!/usr/bin/env bash
set -euo pipefail

activate-service-account.sh

# Initialise GCS bucket and setup id files
init-gcs.sh

# Synchronise local changes with GCS bucket
gsutil -m rsync -d -r /tmp/bucket "gs://${RECHARGE_BUCKET_NAME}"
