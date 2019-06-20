#!/bin/sh
set -euo pipefail

file=${1:-/app/${RECHARGE_SERVICE_KEY_FILE}}

[ -n "$RECHARGE_SERVICE_KEY" ] && {
  # Recharge is set in environment variable
  echo "${RECHARGE_SERVICE_KEY}" > "$file"
}

[ ! -e "$file" ] && {
  # Recharge gcloud service account key file not found
  >&2 echo "ERROR: $file not found"
  exit 1
}

# The working project id may different to the key project_id
if [ -z "${RECHARGE_PROJECT_ID:-}" ]
then
  # Default to projectID defined in service account json
  >&2 echo "WARNING: RECHARGE_PROJECT_ID not set, reading from file"
  RECHARGE_PROJECT_ID=$(jq -r .project_id "$file")
fi

# Set working project
gcloud config set project "${RECHARGE_PROJECT_ID}"

# Authenticate
gcloud auth activate-service-account --key-file "$file"
