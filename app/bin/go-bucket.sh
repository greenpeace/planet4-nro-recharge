#!/usr/bin/env bash
set -euo pipefail

echo "Convert GCS Access Logging data to BQ schema ..."

# Fetch GCS bucket access logging data
gsutil ls "gs://${USAGE_BUCKET_NAME}"
