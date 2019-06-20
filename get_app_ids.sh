#!/usr/bin/env bash
set -euo pipefail

# Pull current recharge bucket data
gsutil -m rsync -d -r gs://p4-nro-recharge bucket

pushd bucket

for path in *
do
  # Ignore if not a directory
  [ -d "$path" ] || continue

  # If the id file already exists,
  [ -e "$path/id.json" ] && {
    # Do nothing
    >&2 echo "WARNING: id file exists in $path"
    jq '.' "$path/id.json"
    continue
  }

  echo "$path"

  # Allow empty values in here, but be noisy about it
  # NROs may not be using the same container prefix as their path, eg Netherlands
  # Will need manual assistance
  set +e
  app_name="$(kubectl -n "$path" get pods | grep master-wordpress-php | head -n1 | cut -d ' ' -f 1 | xargs -I{} kubectl -n "$path" exec {} env | grep NEWRELIC_APPNAME | cut -d= -f2)"
  app_id="$(../app/bin/newrelic-get-application-id.sh "$app_name")"
  set -e

  if [ -z "$app_name" ] || [ -z "$app_id" ]
  then
    # @todo: email someone about this
    >&2 echo "WARNING: empty values for path: $path"
    >&2 echo " - name: '$app_name'"
    >&2 echo " - id:   '$app_id'"
    echo
    echo "Continuing..."
    continue
  fi

  # Create id JSON file in bucket path
  jq -cnM \
    --arg newrelic_id "$app_id" \
    --arg newrelic_name "$app_name" \
    --arg path "$path" \
'{
  newrelic_id: $newrelic_id,
  newrelic_name: $newrelic_name,
  path: $path
}' | tee "$path/id.json"
done

# Sync local changes back to bucket
gsutil -m rsync -d -r bucket gs://p4-nro-recharge
