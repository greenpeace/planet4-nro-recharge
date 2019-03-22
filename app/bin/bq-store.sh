#!/usr/bin/env bash
set -euo pipefail

input_file="${1}"
table="${2}"

dataset="${3:-${RECHARGE_BQ_DATASET}}"
project="${4:-${RECHARGE_PROJECT_ID}}"

echo
echo "Storing $input_file in table: $dataset.$table ..."
echo

bq \
  --project_id="$project" \
  load --source_format=NEWLINE_DELIMITED_JSON "$dataset.$table" "$input_file"
