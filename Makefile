
ifeq ($(strip $(RECHARGE_SERVICE_KEY)),)
$(error RECHARGE_SERVICE_KEY is not set)
endif

ifeq ($(strip $(RECHARGE_BUCKET_PATH)),)
$(error RECHARGE_BUCKET_PATH is not set)
endif

ifeq ($(strip $(NEWRELIC_REST_API_KEY)),)
$(error NEWRELIC_REST_API_KEY is not set)
endif

ifeq ($(strip $(NEWRELIC_APP_ID)),)
ifeq ($(strip $(NEWRELIC_APP_NAME)),)
$(error NEWRELIC_APP_ID and NEWRELIC_APP_NAME not set: You must set at least one of these variables)
endif
endif

.PHONY: all gcloud bucket build run
all: build run

gcloud:
	activate-service-account.sh

bucket: gcloud
	make-bucket.sh

build:
	docker build -t p4-nro-recharge app

run:
	docker run --rm -t \
		-e "NEWRELIC_REST_API_KEY=$(NEWRELIC_REST_API_KEY)" \
		-e "NEWRELIC_APP_ID=$(NEWRELIC_APP_ID)" \
		-e "NEWRELIC_APP_NAME=$(NEWRELIC_APP_NAME)" \
		-e "RECHARGE_BUCKET_PATH=$(RECHARGE_BUCKET_PATH)" \
		-e "RECHARGE_SERVICE_KEY=$(RECHARGE_SERVICE_KEY)" \
		p4-nro-recharge
