#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
. /app/bin/retry.sh

create_recharge_bucket() {
  # Make bucket if it doesn't exist
  gsutil ls -p "${RECHARGE_PROJECT_ID}" "gs://${RECHARGE_BUCKET_NAME}" >/dev/null && return

  echo " * gcs: Initialising WP Stateless bucket"
  echo
  echo " * gcs: Project: ${RECHARGE_PROJECT_ID}"
  echo " * gcs: Labels:"
  echo " * gcs:  - app:         planet4-nro-recharge"
  echo " * gcs:  - app_environment: production"
  echo " * gcs:  - component:   newrelic"
  echo " * gcs: Bucket:  gs://${RECHARGE_BUCKET_NAME}"
  echo " * gcs: Region:  us"

  gsutil mb -l "${RECHARGE_BUCKET_LOCATION}" -p "${RECHARGE_PROJECT_ID}" "gs://${RECHARGE_BUCKET_NAME}"

  # Apply labels
  gsutil label ch \
    -l "app:planet4" \
    -l "app_environment:production" \
    -l "component:recharge" \
    "gs://${RECHARGE_BUCKET_NAME}"
}

function get_recharge_ids() {
  mkdir -p /tmp/bucket/

  # If we're forcing recreation of ID files, don't copy remote to local
  gsutil -m rsync -d -r "gs://${RECHARGE_BUCKET_NAME}" /tmp/bucket

  pushd /tmp/bucket/

  gcloud container clusters get-credentials planet4-production \
    --zone us-central1-a \
    --project planet4-production

  ifs=$IFS
  IFS=$'\n'
  echo "Creating application id files:"
  for deployment in $(kubectl get deployment -l app=planet4,environment=production,component=php --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace | tail -n+2)
  do
    create_application_id_file "$deployment" &
  done
  IFS=$ifs;

  wait
}

function create_application_id_file() {
  local deployment=$1

  local name
  local ns
  local describe
  local app_domain
  local app_id
  local app_name
  local app_path

  name=$(echo "$deployment" | cut -d' ' -f1)
  ns=$(echo "$deployment" | tr -s ' ' | cut -d' ' -f2)

  describe=$(kubectl -n "$ns" describe deployment "$name")

  [ -z "$describe" ] && {
    >&2 echo "ERROR: deployment not found: $deployment"
  }

  app_domain=$(grep APP_HOSTNAME <<<"$describe" | cut -d: -f2 | xargs)
  app_path=$(grep APP_HOSTPATH <<<"$describe" | cut -d: -f2 | xargs)
  app_environment=$(grep APP_ENV <<<"$describe" | cut -d: -f2 | xargs)

  echo " > $name :: $app_domain/$app_path"

  # If the id file already exists,
  [ -e "$app_domain/$app_path/id.json" ] && {
    # Do nothing
    printf "    ✓ id file exists in %s/%s" "$app_domain" "$app_path"
    [[ -z "${FORCE_RECREATE_ID}" ]] && {
      echo ", FORCE_RECREATE_ID is not set, continuing ..."
      return
    }

    echo ", FORCE_RECREATE_ID is set, overwriting ..."

  }

  app_name=$(grep NEWRELIC_APPNAME <<<"$describe" | cut -d: -f2 | xargs)
  [ -z "$app_name" ] && {
    >&2 echo "ERROR: Application name is blank: '$app_name'"
    exit 1
  }

  app_id=$(newrelic-get-application-id.sh "$app_name")
  [ -z "$app_id" ] && {
    >&2 echo "ERROR: Application ID is blank: '$app_id'"
    exit 1
  }

  mkdir -p "$app_domain/$app_path"

  # Create id JSON file in bucket app_path
  jq -cnM \
    --arg newrelic_id "$app_id" \
    --arg newrelic_name "$app_name" \
    --arg app_domain "$app_domain" \
    --arg app_path "$app_path" \
    --arg app_environment "$app_environment" \
'{
newrelic_id: $newrelic_id,
newrelic_name: $newrelic_name,
app_domain: $app_domain,
app_path: $app_path,
app_environment: $app_environment
}' | tee "$app_domain/$app_path/id.json"
}

# Retrying here because gsutil is flaky, connection resets often
echo "Confirm GCS bucket 'gs://${RECHARGE_BUCKET_NAME}' exists ..."
retry create_recharge_bucket

echo "Initialise identifier JSON ..."
retry get_recharge_ids
