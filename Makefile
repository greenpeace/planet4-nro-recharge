SHELL := /bin/bash

.EXPORT_ALL_VARIABLES:

BUILD_NAMESPACE ?= greenpeaceinternational
BUILD_IMAGE ?= p4-nro-recharge

PARENT_IMAGE ?= google/cloud-sdk:alpine

RECHARGE_PROJECT_ID ?= planet4-production
RECHARGE_BUCKET_NAME ?= p4-nro-recharge

# If FAST_INIT is true, don't recreate all buckets/datasets
FAST_INIT ?= 0

# Use Docker buildkit?
DOCKER_BUILDKIT ?= 1

# Version of kubectl to install
KUBECTL_VERSION ?= 1.14.0

# Default period for ETL
RECHARGE_PERIOD ?= day

# Set default dataset for testing
ifeq ($(strip $(RECHARGE_BQ_DATASET)),)
RECHARGE_BQ_DATASET := recharge_test
endif

SECRETS_DIR := secrets
RECHARGE_SERVICE_KEY_FILE := gcloud-service-key.json

# Create service key var from file, if not in env
ifeq ($(strip $(RECHARGE_SERVICE_KEY)),)
ifneq (,$(wildcard $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE)))
RECHARGE_SERVICE_KEY := $(shell cat $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE) | openssl enc -base64 -A)
endif
endif


# ============================================================================

SED_MATCH ?= [^a-zA-Z0-9._-]

ifeq ($(CIRCLECI),true)
# Configure build variables based on CircleCI environment vars
BUILD_NUM = $(CIRCLE_BUILD_NUM)
BRANCH_NAME ?= $(shell sed 's/$(SED_MATCH)/-/g' <<< "$(CIRCLE_BRANCH)")
BUILD_TAG ?= $(shell sed 's/$(SED_MATCH)/-/g' <<< "$(CIRCLE_TAG)")
else
# Not in CircleCI environment, try to set sane defaults
BUILD_NUM = local
BRANCH_NAME ?= $(shell git rev-parse --abbrev-ref HEAD | sed 's/$(SED_MATCH)/-/g')
BUILD_TAG ?= $(shell git tag -l --points-at HEAD | tail -n1 | sed 's/$(SED_MATCH)/-/g')
endif

# If BUILD_TAG is blank there's no tag on this commit
ifeq ($(strip $(BUILD_TAG)),)
# Default to branch name
BUILD_TAG := $(BRANCH_NAME)
else
# Consider this the new :latest image
# FIXME: implement build tests before tagging with :latest
PUSH_LATEST := true
endif

APP_DIR := app

# ============================================================================

# Check necessary commands exist

CIRCLECI := $(shell command -v circleci 2> /dev/null)
DOCKER := $(shell command -v docker 2> /dev/null)
SHELLCHECK := $(shell command -v shellcheck 2> /dev/null)
YAMLLINT := $(shell command -v yamllint 2> /dev/null)

# ============================================================================

all: init build test

init: .git/hooks/pre-commit

.git/hooks/pre-commit:
	@chmod 755 .githooks/*
	@find .git/hooks -type l -exec rm {} \;
	@find .githooks -type f -exec ln -sf ../../{} .git/hooks/ \;

# ============================================================================

clean:
	@$(MAKE) -sj clean-dockerfile clean-bigqueryrc

clean-bigqueryrc:
	@rm -f $(APP_DIR)/.bigqueryrc

clean-dockerfile:
	@rm -f $(APP_DIR)/Dockerfile

clean-serviceaccountkey:
ifneq (,$(wildcard $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE)))
	@-gcloud iam service-accounts keys delete --quiet \
		$(shell jq -r .private_key_id < $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE)) \
		--iam-account=$(shell jq -r .client_email < $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE))
	rm $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE)
endif

# ============================================================================

lint:
	$(MAKE) -j lint-sh lint-yaml lint-docker lint-ci

lint-sh:
	@shellcheck configure
	@find . -type f -name '*.sh' | xargs shellcheck

lint-yaml:
	@find . -type f -name '*.yml' | xargs yamllint

lint-ci:
	yamllint .circleci/config.yml

lint-docker: $(APP_DIR)/Dockerfile
ifndef DOCKER
	$(error "docker is not installed: https://docs.docker.com/install/")
endif
	@docker run --rm -i hadolint/hadolint < $(APP_DIR)/Dockerfile

#	============================================================================

$(APP_DIR)/.bigqueryrc:
	envsubst '$${RECHARGE_PROJECT_ID}' < $@.in > $@

$(APP_DIR)/Dockerfile:
	envsubst '$${BUILD_TAG} $${KUBECTL_VERSION} $${PARENT_IMAGE} $${RECHARGE_SERVICE_KEY_FILE} $${RECHARGE_PROJECT_ID} $${RECHARGE_BUCKET_NAME}' < $@.in > $@

pull:
	docker pull $(PARENT_IMAGE)

build: lint $(APP_DIR)/.bigqueryrc
	docker build \
		-t $(BUILD_NAMESPACE)/$(BUILD_IMAGE):build-$(BUILD_NUM) \
		-t $(BUILD_NAMESPACE)/$(BUILD_IMAGE):$(BUILD_TAG) \
		$(APP_DIR)

push: push-tag push-latest

push-tag:
	docker push $(BUILD_NAMESPACE)/$(BUILD_IMAGE):$(BUILD_TAG)
	docker push $(BUILD_NAMESPACE)/$(BUILD_IMAGE):build-$(BUILD_NUM)

push-latest:
	@if [[ "$(PUSH_LATEST)" = "true" ]]; then { \
		docker tag $(BUILD_NAMESPACE)/$(BUILD_IMAGE):build-$(BUILD_NUM) $(BUILD_NAMESPACE)/$(BUILD_IMAGE):latest; \
		docker push $(BUILD_NAMESPACE)/$(BUILD_IMAGE):latest; \
	}	else { \
		echo "Not tagged.. skipping latest"; \
	} fi

#	============================================================================

test: test-rebuild-id test-run test-clean

test-run:
ifeq ($(strip $(RECHARGE_SERVICE_KEY)),)
	$(error Environment variable RECHARGE_SERVICE_KEY is not set, and $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE) file does not exist)
endif

ifeq ($(strip $(NEWRELIC_REST_API_KEY)),)
	$(error Environment variable NEWRELIC_REST_API_KEY is not set)
endif

ifeq ($(strip $(RECHARGE_BQ_DATASET)),recharge_test)
	$(warning *** Using test dataset: RECHARGE_BQ_DATASET=recharge_test ***)
endif

ifneq ($(strip $(FORCE_RECREATE_ID)),)
	$(warning *** Recreating all appliation ID files! ***)
endif

	time docker run --name recharge-test --rm \
		-e "FAST_INIT=$(FAST_INIT)" \
		-e "FORCE_RECREATE_ID=$(FORCE_RECREATE_ID)" \
		-e "RECHARGE_BQ_DATASET=$(RECHARGE_BQ_DATASET)" \
		-e "NEWRELIC_REST_API_KEY=$(NEWRELIC_REST_API_KEY)" \
		-e "NEWRELIC_APP_ID=$(NEWRELIC_APP_ID)" \
		-e "NEWRELIC_APP_NAME=$(NEWRELIC_APP_NAME)" \
		-e "RECHARGE_BUCKET_NAME=p4-nro-recharge-test" \
		-e 'RECHARGE_SERVICE_KEY=$(RECHARGE_SERVICE_KEY)' \
		-e "RECHARGE_PERIOD=$(RECHARGE_PERIOD)" \
		-e "RECHARGE_PERIOD_DAY=$(RECHARGE_PERIOD_DAY)" \
		-e "RECHARGE_PERIOD_MONTH=$(RECHARGE_PERIOD_MONTH)" \
		-e "RECHARGE_PERIOD_YEAR=$(RECHARGE_PERIOD_YEAR)" \
		$(BUILD_NAMESPACE)/$(BUILD_IMAGE):build-$(BUILD_NUM)

test-clean:
	$(warning Not yet implemented. @TODO delete testing bucket and bq data)

test-rebuild-id:
ifeq ($(strip $(RECHARGE_SERVICE_KEY)),)
	$(error Environment variable RECHARGE_SERVICE_KEY is not set, and $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE) file does not exist)
endif

ifeq ($(strip $(NEWRELIC_REST_API_KEY)),)
	$(error Environment variable NEWRELIC_REST_API_KEY is not set)
endif

ifeq ($(strip $(RECHARGE_BQ_DATASET)),recharge_test)
	$(warning *** Using test dataset: RECHARGE_BQ_DATASET=recharge_test ***)
endif

ifneq ($(strip $(FORCE_RECREATE_ID)),)
	$(warning *** Recreating all appliation ID files! ***)
endif

	time docker run --name recharge-test --rm \
		-e "FAST_INIT=$(FAST_INIT)" \
		-e "FORCE_RECREATE_ID=1" \
		-e "RECHARGE_BQ_DATASET=$(RECHARGE_BQ_DATASET)" \
		-e "NEWRELIC_REST_API_KEY=$(NEWRELIC_REST_API_KEY)" \
		-e "RECHARGE_BUCKET_NAME=p4-nro-recharge-test" \
		-e 'RECHARGE_SERVICE_KEY=$(RECHARGE_SERVICE_KEY)' \
		-e "RECHARGE_PERIOD=$(RECHARGE_PERIOD)" \
		-e "RECHARGE_PERIOD_DAY=$(RECHARGE_PERIOD_DAY)" \
		-e "RECHARGE_PERIOD_MONTH=$(RECHARGE_PERIOD_MONTH)" \
		-e "RECHARGE_PERIOD_YEAR=$(RECHARGE_PERIOD_YEAR)" \
		$(BUILD_NAMESPACE)/$(BUILD_IMAGE):build-$(BUILD_NUM) \
		rebuild-id.sh

#	============================================================================

rebuild-dataset: # Recreates the entire dataset with values from GCS bucekt
ifeq ($(strip $(NEWRELIC_REST_API_KEY)),)
	$(error Environment variable NEWRELIC_REST_API_KEY is not set)
endif

ifeq ($(strip $(RECHARGE_SERVICE_KEY)),)
	$(error Environment variable RECHARGE_SERVICE_KEY is not set, and $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE) file does not exist)
endif

ifeq ($(strip $(RECHARGE_BQ_DATASET)),recharge_test)
	$(warning *** Using test dataset: RECHARGE_BQ_DATASET=recharge_test ***)
endif

ifneq ($(strip $(FORCE_RECREATE_ID)),)
	$(warning *** Recreating all appliation ID files! ***)
endif
		time docker run --name recharge-test --rm -ti \
			-e "FAST_INIT=$(FAST_INIT)" \
			-e "FORCE_RECREATE_ID=$(FORCE_RECREATE_ID)" \
			-e "RECHARGE_BQ_DATASET=$(RECHARGE_BQ_DATASET)" \
			-e "RECHARGE_BUCKET_NAME=$(RECHARGE_BUCKET_NAME)" \
			-e "NEWRELIC_REST_API_KEY=$(NEWRELIC_REST_API_KEY)" \
			-e 'RECHARGE_SERVICE_KEY=$(RECHARGE_SERVICE_KEY)' \
			$(BUILD_NAMESPACE)/$(BUILD_IMAGE):build-$(BUILD_NUM) \
			rebuild-dataset.sh
