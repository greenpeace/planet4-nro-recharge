#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

function open_sem() {
  mkfifo pipe-$$
  exec 3<>pipe-$$
  rm pipe-$$
  local i=$1
  for((;i>0;i--)); do
      printf %s 000 >&3
  done
}

function run_with_lock() {
  local x
  read -r -u 3 -n 3 x && ((0==x)) || exit "$x"
  (
   ( "$@"; )
  printf '%.3d' $? >&3
  )&
}

function main() {

  declare -a apps
  mapfile -t apps < <(get_applications)

  # Portfoward to elastic master in cluster
  echo "Opening portfoward to elastic"

  # Comment this out for production
  # gcloud container clusters get-credentials p4-development --zone us-central1-a --project planet-4-151612
  POD_NAME=$(kubectl get pods --namespace elastic -l "app=elasticsearch-client,release=p4-es-client" -o jsonpath="{.items[0].metadata.name}") # for dev

  kubectl port-forward --namespace elastic "$POD_NAME" 9200:9200 & # for prod
  # kubectl port-forward --namespace elastic "$POD_NAME" 9200:9200 & # for dev

  kube_pid="$!"
  echo "Opened, PID is: $kube_pid"

  N=4
  open_sem $N

  for app in "${apps[@]}"
  do
      run_with_lock queue_application "$app" 
  done

  echo "Waiting..."
  sleep 5
  echo "Killing port forward, PID: $kube_pid"
  kill -9 "$kube_pid"
  wait

  echo " ✓ Finished go-elastic.sh"
}

function get_applications() {

  while IFS= read -r -d '' file
  do
    # Fetching all application data
    >&2 echo " ✓ ${file##/tmp/bucket/}"

    # Return JSON for application
    echo "$file"

  done < <(find /tmp/bucket -type f -name 'id.json' -print0 | sort -z)
}

function queue_application() {
  local app_file=$1

  local app_domain
  local app_path
  local app_environment

  set +e
  app_domain=$(jq -r '.app_domain' "$app_file")
  app_path=$(jq -r '.app_path' "$app_file")
  app_environment=$(jq -r '.app_environment' "$app_file")

  [ -z "$app_domain" ] && {
    >&2 echo "ERROR: app_domain is blank in $app_file"
    >&2 cat "$app_file"
  }

  elastic_servicename=$(jq -r '.elastic_servicename' "$app_file")
  [ -z "$elastic_servicename" ] && {
    >&2 echo "ERROR: elastic_servicename is blank in $app_file"
    >&2 cat "$app_file"
  }
  set -e

  >&2 echo "$elastic_servicename - Processing ..."

  # Fetch SLA data for application on date
  elastic-sla-get.sh "$elastic_servicename" "$app_environment"

  echo "$elastic_servicename ✓ Fetch complete"

  # Transform NewRelic data to BigQuery table format
  elastic-sla-etl.sh "$elastic_servicename" "$app_domain/$app_path"

  echo "$elastic_servicename ✓ $app_domain/$app_path complete"
}

main
