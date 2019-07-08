#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

months=(01 02 03 04 05 06 07 08 09 10 11 12)
# Initial data gathering from 2018
years=(2018)

# Begin
nextyear=$(date +%Y)

while
    years+=("$nextyear")
    thisyear="$nextyear"
    nextyear=$(( nextyear + 1 ))
    (( "$nextyear" <= "$thisyear" ))
do
    :
done

# shellcheck disable=SC1091
. /app/bin/retry.sh

# Authenticates with GCP service account
activate-service-account.sh

# This is fine. It's fine. Everything's fine.
rm -fr /tmp/batch/* || true
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

# Synchronise GCS SLA bucket to local directory
# echo
# echo " ************** DEBUG ************"
# echo "      DISABLED BUCKET SYNC"
# echo
# retry gsutil -m rsync -d -r "gs://${RECHARGE_BUCKET_NAME}" "/tmp/bucket"

pushd "/tmp/bucket" > /dev/null

today=$(date +%Y-%m-%d)

# For each subdirectory
for year in "${years[@]}"
do
  echo " 1. ${year:0:4} ..."
  echo " 2. ${today:0:4} ..."

  for month in "${months[@]}"
  do
    todate=$(date -d "${year}-${month}-01" +%s)
    cond=$(date -d "$today" +%s)

    (( "$todate" > "$cond" )) && {
      >&2 echo "Month $year-$month is in the future, skipping ..."
      continue
    }

    echo
    echo "=================================================================="
    echo
    echo " > $year/$month"
    echo

    # Get SLA data for month
    RECHARGE_PERIOD="month"
    export RECHARGE_PERIOD

    RECHARGE_PERIOD_MONTH="${year: -4}-${month: -2}" \
    . /app/bin/get_dates.sh

    go-newrelic.sh

    # for day in "$month"/*
    # do
    #   echo "$day ..."
    #
    #   echo "skipping day data ..."
    #   continue
    #
    #   # Not a dir? ignore
    #   [ -d "$day" ] || continue
    #
    #   # isNumeric
    #   [[ ${day: -2} =~ ^[0-9]+$ ]] || continue
    #
    #   echo
    #   echo "=================================================================="
    #   echo
    #   echo " > $day"
    #   echo
    #   # Get SLA data for day
    #   RECHARGE_PERIOD=day \
    #   RECHARGE_PERIOD_DAY="${year: -4}-${month: -2}-${day: -2}" \
    #   . /app/bin/get_dates.sh
    #
    #   if ! retry newrelic-sla-get.sh "$app_id"
    #   then
    #     echo "WARNING: could not fetch NewRelic SLA data for $bucket"
    #     continue
    #   fi
    #
    #   [ -e "${RECHARGE_OUTPUT_FILE}" ] && {
    #     mv "${RECHARGE_OUTPUT_FILE}" "$day/newrelic-sla.json"
    #     # Upload SLA data for day
    #     retry newrelic-sla-etl.sh "$bucket" "day" "$day/newrelic-sla.json"
    #   }
    #
    # done # end day
  done # end month

  echo
  echo "=================================================================="
  echo
  echo " > $year"
  echo


  # isFuture?
  (( ${year:0:4} >= ${today:0:4} )) && {
    >&2 echo "Year $year is in the future, skipping ..."
    continue
  }

  # Get SLA data for year
  RECHARGE_PERIOD="year"
  export RECHARGE_PERIOD

  RECHARGE_PERIOD_YEAR=${year: -4} \
  . /app/bin/get_dates.sh

  retry go-newrelic.sh

done # end year

# echo
# echo " ************** DEBUG ************"
# echo "      DISABLED BUCKET SYNC"
# echo
retry gsutil -m rsync -d -r "/tmp/bucket" "gs://${RECHARGE_BUCKET_NAME}" &

bq-store-batch.sh

echo "Done"
date
