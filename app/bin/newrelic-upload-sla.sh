#!/usr/bin/env bash
set -euo pipefail


path_prefix="$RECHARGE_BUCKET_PATH/sla"

year="${DATE_START//-*/}"
month="$(echo "${DATE_START}" | cut -d- -f2)"
day="$(echo "${DATE_START}" | cut -d- -f3)"

case $RECHARGE_PERIOD in
  year)
    path_stub="$year"
    ;;
  month)
    path_stub="$year/$month"
    ;;
	day)
    path_stub="$year/$month/$day"
    ;;
  *)
    >&2 echo "ERROR: unhandled RECHARGE_PERIOD: $RECHARGE_PERIOD"
    exit 1
    ;;
esac

echo "Uploading SLA data for application to gs://$RECHARGE_BUCKET_NAME/$path_prefix/$path_stub/newrelic-sla.json"

gsutil cp "$RECHARGE_OUTPUT_FILE" "gs://$RECHARGE_BUCKET_NAME/$path_prefix/$path_stub/newrelic-sla.json"
