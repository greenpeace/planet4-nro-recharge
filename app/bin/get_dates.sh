#!/bin/sh
set -euo pipefail

echo "Period: ${RECHARGE_PERIOD}"

case $RECHARGE_PERIOD in
	day)
    if [ -z "${RECHARGE_PERIOD_DAY}" ]
    then
      # Default to yesterday
      DATE_START="$(date -d 'yesterday' +'%Y-%m-%d')"
    else
			echo "Day:    ${RECHARGE_PERIOD_DAY}"
      # RECHARGE_PERIOD_DAY expects full date string such as 2018-01-01
      DATE_START="${RECHARGE_PERIOD_DAY}"
    fi
    DATE_END="$DATE_START"
		;;
	month)
    if [ -z "${RECHARGE_PERIOD_MONTH}" ]
    then
      # Default to last month
      DATE_START="$(date "+%Y-%m-01" -d "-1 Month")"
    else
			echo "Month:  ${RECHARGE_PERIOD_MONTH}"
      # RECHARGE_PERIOD_MONTH Expects YEAR-MONTH string such as 2018-12
      DATE_START="$(date "+%Y-%m-01" -d "${RECHARGE_PERIOD_MONTH}-01")"
    fi
    DATE_END="$(date "+%Y-%m-%d" -d "$DATE_START +1 month -1 day")"
		;;
	year)
    if [ -z "${RECHARGE_PERIOD_YEAR}" ]
    then
      # Default to last year
      DATE_START="$(date "+%Y-01-01" -d "-1 Year")"
    else
			echo "Year:   ${RECHARGE_PERIOD_YEAR}"
      # RECHARGE_PERIOD_YEAR Expects YEAR string such as 2018
      DATE_START="$(date "+%Y-01-01" -d "${RECHARGE_PERIOD_YEAR}-01-01")"
    fi
    DATE_END="$(date "+%Y-%m-%d" -d "$DATE_START +1 year -1 day")"
    ;;
	*)
		>&2 echo "ERROR: unhandled recharge period: $RECHARGE_PERIOD"
    exit 1
		;;
  esac

echo "From:   ${DATE_START}"
echo "To:     ${DATE_END}"

export DATE_START
export DATE_END
