#!/usr/bin/env bash
set -euo pipefail

input_file="${1}"
table="${2}"
dataset="${3:-${RECHARGE_BQ_DATASET}}"

echo
echo "Storing $input_file in $dataset.${table}_v${SCHEMA_VERSION} ..."

ls -l "$input_file"

bq load \
  --source_format=NEWLINE_DELIMITED_JSON \
  "$dataset.${table}_v${SCHEMA_VERSION}" "$input_file"
