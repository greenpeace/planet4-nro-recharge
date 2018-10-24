#!/bin/sh
set -euo pipefail

# Default Docker CMD will be /sbin/my_init
if [ "$1" = "newrelic-get-application-sla.sh" ]
then
  echo "Executing command:"
  echo "$*"
	exec go.sh
else
  # Execute the custom CMD
  echo "Executing command:"
  echo "$*"
	exec /bin/sh -c "$*"
fi
