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

  N=4
  open_sem $N

  for app in "${apps[@]}"
  do
      run_with_lock queue_application "$app"
  done

  wait

  echo " ✓ Finished go-newrelic.sh"
}

function get_applications() {
  # If NEWRELIC_APP_ID is not blank

  # Fetch NewRelic application IDs from id.json
  while IFS= read -r -d '' file
  do
    [[ -n "${NEWRELIC_APP_ID}" ]] && {
      # Fetch data for a single application
      [[ $(jq -r '.newrelic_id' "$file") = "${NEWRELIC_APP_ID}" ]] && {
        # Found matching file
        >&2 echo " ✓ $(jq -r '.newrelic_name' "$file")"
        >&2 echo

        # Print file output
        echo "$file"

        return
      }
      # Not the correct file
      continue
    }

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
  local newrelic_id
  local newrelic_name

  set +e
  app_domain=$(jq -r '.app_domain' "$app_file")
  app_path=$(jq -r '.app_path' "$app_file")

  [ -z "$app_domain" ] && {
    >&2 echo "ERROR: app_domain is blank in $app_file"
    >&2 cat "$app_file"
  }

  newrelic_id=$(jq -r '.newrelic_id' "$app_file")
  [ -z "$newrelic_id" ] && {
    >&2 echo "ERROR: newrelic_id is blank in $app_file"
    >&2 cat "$app_file"
  }

  newrelic_name=$(jq -r '.newrelic_name' "$app_file")
  [ -z "$newrelic_name" ] && {
    >&2 echo "ERROR: newrelic_name is blank in $app_file"
    >&2 cat "$app_file"
  }
  set -e

  >&2 echo "$newrelic_id - Processing $newrelic_name ..."

  # Fetch SLA data for application on date
  newrelic-sla-get.sh "$newrelic_id"

  echo "$newrelic_id ✓ Fetch complete"

  # Stores SLA data in bucket
  # newrelic-sla-upload.sh "$newrelic_id" "$app_domain/$app_path"

  # Transform NewRelic data to BigQuery table format
  newrelic-sla-etl.sh "$newrelic_id" "$app_domain/$app_path"

  echo "$newrelic_id ✓ $app_domain/$app_path complete"
}

# If NEWRELIC_APP_ID is set
main
