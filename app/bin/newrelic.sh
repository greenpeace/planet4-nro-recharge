#!/usr/bin/env bash
set -euo pipefail

# Fetch SLA data for application on date
newrelic-sla-get.sh

# Stores SLA data in bucket
newrelic-sla-upload.sh

# Transform NewRelic data to BigQuery table format
newrelic-sla-etl.sh

bq-store.sh
