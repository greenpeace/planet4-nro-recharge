#!/bin/sh
set -eo pipefail

file=${1:-/app/gcloud-service-key.json}

if [ -z "${RECHARGE_SERVICE_KEY}" ]
then
  >&2 echo "ERROR :: environment variable GCLOUD_SERVICE_KEY not set"
  exit 1
fi

# Decode base64-encoded service key json
echo "${RECHARGE_SERVICE_KEY}" | base64 -d > "$file"

# The working project id may different to the key project_id
if [ -z "${RECHARGE_PROJECT_ID}" ]
then
  # Default to service account project
  echo "Warning:  RECHARGE_PROJECT_ID not set"
  RECHARGE_PROJECT_ID=$(jq -r .project_id $file)
fi

# Configure project
gcloud config set project "${RECHARGE_PROJECT_ID}"

# Authenticate
gcloud auth activate-service-account --key-file "$file"
