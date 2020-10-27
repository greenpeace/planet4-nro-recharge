#!/usr/bin/env bash
set -euo pipefail


echo "Greenpeace Planet4 NRO Recharge Application"
echo "Version: ${APP_VERSION}"
echo
echo "Components:"
jq --version
bq version
printf "kubectl %s" "$(kubectl version --client --short)"
echo

# Default Docker CMD will be go.sh
if [ "$1" = "go.sh" ]
then
	exec "$@"
else
  # Execute the custom CMD
  echo "Executing command:"
  echo "$*"
	exec /bin/sh -c "$*"
fi
