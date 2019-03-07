#!/bin/sh
set -euo pipefail

# Default Docker CMD will be go.sh
if [ "$1" = "go.sh" ]
then
  shift
	exec go.sh "$@"
else
  # Execute the custom CMD
  echo "Executing command:"
  echo "$*"
	exec /bin/sh -c "$*"
fi
