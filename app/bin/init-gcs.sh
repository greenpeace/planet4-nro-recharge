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

  # Comment this out for production
  # gcloud container clusters get-credentials p4-development --zone us-central1-a --project planet-4-151612
  ifs=$IFS
  IFS=$'\n'
  echo
  echo "=================================================================="
  echo
  echo "Creating application id files:"
  echo
  # for deployment in $(kubectl get deployment -l app=planet4,environment=development,component=php --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace | tail -n+2)
  # do
  #   create_application_id_file "$deployment" &
  # done
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
  local app_path
  local elastic_servicename

  name=$(echo "$deployment" | cut -d' ' -f1)
  ns=$(echo "$deployment" | tr -s ' ' | cut -d' ' -f2)
  secret=$(echo ${deployment%"-wordpress-php"} | tr -d '[:space:]')

  describe=$(kubectl -n "$ns" describe deployment "$name")
  mysql_user=$(kubectl -n "$ns" get secret "$secret-db" --template="{{.data.username | base64decode }}")

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

    [[ -z "${FORCE_RECREATE_ID}" ]] && echo && return

    echo ", FORCE_RECREATE_ID is set, overwriting ..."

  }


  mkdir -p "$app_domain/$app_path"

  elastic_servicename="$mysql_user-$app_environment"
  echo "Elastic Service Name: $elastic_servicename"
  # Create id JSON file in bucket app_path
  jq -cnM \
    --arg app_domain "$app_domain" \
    --arg app_path "$app_path" \
    --arg app_environment "$app_environment" \
    --arg elastic_servicename "$elastic_servicename" \
'{
app_domain: $app_domain,
app_path: $app_path,
app_environment: $app_environment,
elastic_servicename: $elastic_servicename
}' | tee "$app_domain/$app_path/id.json"
}

# Retrying here because gsutil is flaky, connection resets often
echo "Confirm GCS bucket 'gs://${RECHARGE_BUCKET_NAME}' exists ..."
retry create_recharge_bucket

echo "Initialise identifier JSON ..."
retry get_recharge_ids

echo
echo "=================================================================="
echo
