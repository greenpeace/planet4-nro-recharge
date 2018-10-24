FROM google/cloud-sdk:alpine

RUN apk add --no-cache \
  bash \
  coreutils \
  curl \
  jq

COPY . /

WORKDIR /app

ENTRYPOINT ["entrypoint.sh"]

CMD ["go.sh"]

ENV \
  NEWRELIC_APP_ID="" \
  NEWRELIC_APP_NAME="" \
  NEWRELIC_REST_API_KEY="" \
  PATH="/app/bin:$PATH" \
  RECHARGE_BUCKET_LOCATION="us" \
  RECHARGE_BUCKET_NAME="planet4-nro-recharge" \
  RECHARGE_BUCKET_PATH="" \
  RECHARGE_OUTPUT_FILE="/tmp/sla.json" \
  RECHARGE_PERIOD_DAY="" \
  RECHARGE_PERIOD_MONTH="" \
  RECHARGE_PERIOD_YEAR="" \
  RECHARGE_PERIOD="month" \
  RECHARGE_PROJECT_ID="planet4-production" \
  RECHARGE_SERVICE_KEY="" \
