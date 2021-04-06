#!/usr/bin/env bash
set -euo pipefail

elastic_servicename="$1"
app_environment="$2"


from="${DATE_START}T00:00:00+00:00Z"
to="${DATE_END}T23:59:59+00:00Z"

now=$(date +%s)
end=$(date -d "${DATE_END} 23:59:59" +%s)

[[ $end -ge "$now" ]] && {
  >&2 echo "WARNING: End date is in the future. Skipping ..."
  >&2 echo "$end >= $now"
  exit 0
}

mkdir -p /tmp

echo "$elastic_servicename - Fetching Elastic Transaction data ..."
echo "$elastic_servicename - App:    elastic_servicename"
echo "$elastic_servicename - Dates:  FROM: $from TO: $to"

outfile="/tmp/sla-$RECHARGE_PERIOD-${end}-${elastic_servicename}-${}.json"


curl -s -X GET "http://localhost:9200/apm-*-transaction-*/_count" \
     -H 'Content-Type: application/json' \
     -d'
{
    "query": {
        "bool": {
            "must": [
                {
                    "term": {
                        "service.name": "'$elastic_servicename'"
                    }
                },
                {
                    "term": {
                        "service.environment": "'$app_environment'"
                    }
                },
                {
                    "range": {
                        "@timestamp": {
                            "gte": "'$from'",
                            "lte": "'$to'"
                        }
                    }
                }
            ]
        }
    }
}
     '
     -o "$outfile"

 if jq -e . "$outfile" > /dev/null
 then
   jq -e '.error' "$outfile" > /dev/null && {
     >&2 echo "$app_id ✗ ERROR: Elastic API said: $(jq '.error.type' "$outfile")"
     echo
     exit 1
   }
 else
     >&2 echo "Failed to parse JSON, or got false/null"
     >&2 cat "$outfile"
     exit 1
 fi

>&2 echo "$app_id ✓ Recharge data gathered successfully"
