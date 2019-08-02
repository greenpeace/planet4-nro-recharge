#!/usr/bin/env bash
# shellcheck disable=SC2086

set -euo pipefail

tables=(
  appdex
  enduser
)

mkdir -p /tmp/batch/

for t in "${tables[@]}"
do
  [[ $(find /tmp -name etl-$t-\* | wc -l) -gt 0 ]] || {
    echo "No files matching etl-$t-*.json in /tmp/ ?"
    ls -al /tmp/

    echo "Skipping ..."
    continue
  }

  echo "Processing $t ..."

  files=$(ls /tmp/etl-"$t"-*.json)

  # Concatonate files
  if ! jq -sMc 'group_by(.site)[] | add' $files > "/tmp/batch/$t.json"
  then
    >&2 echo "ERROR creating $t.json"
    count=1
    while IFS= read -r -d '' file
    do
      if ! jq -e . "$file" > /dev/null
      then
        >&2 printf '%-3d ✗ ERROR parsing: %s\n' $count "$file"
        cat "$file"
        jq -e "$file" || true
        echo
      else
        >&2 printf '%-3d ✓ %s\n' $count "$file"
      fi
      count=$(( count + 1 ))
    done < <(find /tmp -name etl-$t-\* -print0)

    exit 1
  fi

  # Upload to BigQuery
  bq-store-single.sh "/tmp/batch/$t.json" "newrelic_$t"
done
