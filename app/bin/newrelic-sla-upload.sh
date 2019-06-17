#!/usr/bin/env bash
set -euo pipefail

newrelic_id=$1

sla_file="/tmp/sla-$newrelic_id.json"
[ -e "$sla_file" ] || {
  >&2 echo "$newrelic_id ✗ ERROR: file not found: $sla_file"
  exit 1
}

path_prefix="$2"
[ -d "/tmp/bucket/$path_prefix" ] || {
  >&2 echo "$newrelic_id ✗ ERROR: path does not exist: /tmp/bucket/$path_prefix"
  exit 1
}

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
    >&2 echo "$newrelic_id ✗ ERROR: unhandled RECHARGE_PERIOD: $RECHARGE_PERIOD"
    exit 1
    ;;
esac

gsutil cp "$sla_file" "gs://$RECHARGE_BUCKET_NAME/$path_prefix/$path_stub/newrelic-sla.json" 2>/dev/null

>&2 echo "$newrelic_id ✓ Recharge data uploaded successfully"
