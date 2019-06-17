#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# shellcheck disable=SC1091
. /app/bin/retry.sh

# Authenticates with GCP service account
activate-service-account.sh

# This is fine. It's fine. Everything's fine.
rm -fr /tmp/batch || true
mkdir -p /tmp/batch || true

# DELETE THE ENTIRE DATASET
read -n 1 -rp "${1:-" *** REALLY Delete entire dataset ${RECHARGE_BQ_DATASET} ?"} [y/N] " yn
case "$yn" in
    [Yy] ) bq rm -rf "${RECHARGE_BQ_DATASET}" ;;
    * ) : ;;
esac

# Initialise bucket and dataset, unless FAST_INIT is set to 'true'
[[ "${FAST_INIT}" = true ]] || {
  # Ensures the bucket for storing data exists
  init-gcs.sh

  # Ensures the bucket for storing data exists
  init-bq.sh
}

wait

pushd "/tmp/bucket" > /dev/null

echo
echo " ==="
echo
today=$(date -d 'now' +%s)

for bucket in *
do

  # Not a dir? ignore
  [ -d "$bucket" ] || continue

  # Do we have the application id?
  [ -e "$bucket/id.json" ] && {
    # Store for later use
    app_id=$(jq -r '.newrelic_id' "$bucket/id.json")

    [ -z "$app_id" ] && {
      >&2 echo "WARNING: app_id is blank! FIXME Seymour!"
      continue
    }
  }

  # Prepare folders
  # FIXME: Hack!! Generate year range programmatically
  years=(2018 2019 2020 2021 2022 2023 2024 2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035 2036 2037 2038 2039)
  months=(01 02 03 04 05 06 07 08 09 10 11 12)
  for y in "${years[@]}"
  do
    for m in "${months[@]}"
    do
      [[ "$(date -d "$y-$m-01" +%s)" -ge "$today" ]] || mkdir -p "$bucket/sla/$y/$m"
    done
  done

  for year in "$bucket"/sla/*
  do
    # Not a dir? ignore
    [ -d "$year" ] || continue

    # isNumeric
    [[ ${year: -4} =~ ^[0-9]+$ ]] || continue

    echo
    echo "=================================================================="
    echo
    echo " > $year"
    echo

    # Get SLA data for year
    RECHARGE_PERIOD=year \
    RECHARGE_PERIOD_YEAR=${year: -4} \
    . /app/bin/get_dates.sh

    retry newrelic-sla-get.sh "$app_id"

    [ -e "${RECHARGE_OUTPUT_FILE}" ] && {
      mv "${RECHARGE_OUTPUT_FILE}" "$year/newrelic-sla.json"
      retry newrelic-sla-etl.sh "$bucket" "year" "$year/newrelic-sla.json"
    }

    for month in "$year"/*
    do
      # Not a dir? ignore
      [ -d "$month" ] || continue

      # isNumeric
      [[ ${month: -2} =~ ^[0-9]+$ ]] || continue
      echo
      echo "=================================================================="
      echo
      echo " > $month"
      echo

      # Get SLA data for month
      RECHARGE_PERIOD=month \
      RECHARGE_PERIOD_MONTH="${year: -4}-${month: -2}" \
      . /app/bin/get_dates.sh

      retry newrelic-sla-get.sh "$app_id"

      [ -e "${RECHARGE_OUTPUT_FILE}" ] && {
        mv "${RECHARGE_OUTPUT_FILE}" "$month/newrelic-sla.json"
        # Upload SLA data for month
        retry newrelic-sla-etl.sh "$bucket" "month" "$month/newrelic-sla.json"
      }

      for day in "$month"/*
      do
        # Not a dir? ignore
        [ -d "$day" ] || continue

        # isNumeric
        [[ ${day: -2} =~ ^[0-9]+$ ]] || continue

        echo
        echo "=================================================================="
        echo
        echo " > $day"
        echo
        # Get SLA data for day
        RECHARGE_PERIOD=day \
        RECHARGE_PERIOD_DAY="${year: -4}-${month: -2}-${day: -2}" \
        . /app/bin/get_dates.sh

        retry newrelic-sla-get.sh "$app_id"
        [ -e "${RECHARGE_OUTPUT_FILE}" ] && {
          mv "${RECHARGE_OUTPUT_FILE}" "$day/newrelic-sla.json"
          # Upload SLA data for day
          retry newrelic-sla-etl.sh "$bucket" "day" "$day/newrelic-sla.json"
        }

      done
    done
  done
done

retry gsutil -m rsync -d -r "/tmp/bucket" "gs://${RECHARGE_BUCKET_NAME}" &

bq-store-batch.sh &

wait

echo "Done"
date
