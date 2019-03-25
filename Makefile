SHELL := /bin/bash

BUILD_NAMESPACE ?= gcr.io
BUILD_PROJECT ?= planet-4-151612
BUILD_IMAGE ?= p4-nro-recharge

PARENT_IMAGE ?= google/cloud-sdk:alpine
export PARENT_IMAGE

RECHARGE_SERVICE_KEY_FILE := gcloud-service-key.json
export RECHARGE_SERVICE_KEY_FILE

# Set default dataset for testing
ifeq ($(strip $(RECHARGE_BQ_DATASET)),)
RECHARGE_BQ_DATASET := recharge_test
endif

SECRETS_DIR := secrets

# convert NRO name to lowercase, remove punctuation, replace space with hyphen
ifneq ($(wildcard APP_PATH),)
NRO ?= $(shell cat APP_PATH)
endif

ifneq ($(wildcard $(SECRETS_DIR)/env.$(NRO)),)
include $(SECRETS_DIR)/env.$(NRO)
export $(shell sed 's/=.*//' secrets/env.$(NRO))
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

REVISION_TAG = $(shell git rev-parse --short HEAD)

export BUILD_NUM
export BUILD_TAG

APP_DIR := app

# ============================================================================

# Check necessary commands exist

CIRCLECI := $(shell command -v circleci 2> /dev/null)
DOCKER := $(shell command -v docker 2> /dev/null)
SHELLCHECK := $(shell command -v shellcheck 2> /dev/null)
YAMLLINT := $(shell command -v yamllint 2> /dev/null)

# ============================================================================

all: init build run

init: .git/hooks/pre-commit

.git/hooks/pre-commit:
	@chmod 755 .githooks/*
	@find .git/hooks -type l -exec rm {} \;
	@find .githooks -type f -exec ln -sf ../../{} .git/hooks/ \;

clean:
	@$(MAKE) -j clean-dockerfile clean-serviceaccountkey

clean-dockerfile:
	@rm -f $(APP_DIR)/Dockerfile

clean-serviceaccountkey:
ifneq (,$(wildcard $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE)))
	@-gcloud iam service-accounts keys delete --quiet \
		$(shell jq -r .private_key_id < $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE)) \
		--iam-account=$(shell jq -r .client_email < $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE))
	rm $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE)
endif

lint: lint-sh lint-yaml lint-docker

lint-sh:
	@shellcheck configure
	@find . -type f -name '*.sh' | xargs shellcheck

lint-yaml:
	@find . -type f -name '*.yml' | xargs yamllint

lint-docker: $(APP_DIR)/Dockerfile
ifndef DOCKER
	$(error "docker is not installed: https://docs.docker.com/install/")
endif
	@docker run --rm -i hadolint/hadolint < $(APP_DIR)/Dockerfile

$(APP_DIR)/Dockerfile:
	envsubst '$${PARENT_IMAGE} $${RECHARGE_SERVICE_KEY_FILE}' < $@.in > $@

pull:
	docker pull ${PARENT_IMAGE}

build: lint
	docker build \
		-t $(BUILD_NAMESPACE)/$(BUILD_PROJECT)/$(BUILD_IMAGE):build-$(BUILD_NUM) \
		-t $(BUILD_NAMESPACE)/$(BUILD_PROJECT)/$(BUILD_IMAGE):$(REVISION_TAG) \
		-t $(BUILD_NAMESPACE)/$(BUILD_PROJECT)/$(BUILD_IMAGE):$(BUILD_TAG) \
		$(APP_DIR)

push: push-tag push-latest

push-tag:
	docker push $(BUILD_NAMESPACE)/$(BUILD_PROJECT)/$(BUILD_IMAGE):$(BUILD_TAG)
	docker push $(BUILD_NAMESPACE)/$(BUILD_PROJECT)/$(BUILD_IMAGE):$(REVISION_TAG)
	docker push $(BUILD_NAMESPACE)/$(BUILD_PROJECT)/$(BUILD_IMAGE):build-$(BUILD_NUM)

push-latest:
	@if [[ "$(PUSH_LATEST)" = "true" ]]; then { \
		docker tag $(BUILD_NAMESPACE)/$(BUILD_PROJECT)/$(BUILD_IMAGE):$(REVISION_TAG) $(BUILD_NAMESPACE)/$(BUILD_PROJECT)/$(BUILD_IMAGE):latest; \
		docker push $(BUILD_NAMESPACE)/$(BUILD_PROJECT)/$(BUILD_IMAGE):latest; \
	}	else { \
		echo "Not tagged.. skipping latest"; \
	} fi

run:
ifeq ($(strip $(RECHARGE_SERVICE_KEY)),)
ifeq (,$(wildcard $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE)))
	$(error Environment variable RECHARGE_SERVICE_KEY is not set, and $(RECHARGE_SERVICE_KEY_FILE) file does not exist)
endif
endif

ifeq ($(strip $(RECHARGE_BUCKET_PATH)),)
	$(error Environment variable RECHARGE_BUCKET_PATH is not set)
endif

ifeq ($(strip $(NEWRELIC_REST_API_KEY)),)
	$(error Environment variable NEWRELIC_REST_API_KEY is not set)
endif

ifeq ($(strip $(NEWRELIC_APP_ID)),)
ifeq ($(strip $(NEWRELIC_APP_NAME)),)
	$(error Environment variables NEWRELIC_APP_ID and NEWRELIC_APP_NAME not set: You must set at least one of these variables)
endif
endif

ifeq ($(strip $(RECHARGE_BQ_DATASET)),recharge_test)
	$(warning *** Using test dataset: RECHARGE_BQ_DATASET=recharge_test ***)
endif

	docker run --rm -t \
		-e "RECHARGE_BQ_DATASET=$(RECHARGE_BQ_DATASET)" \
		-e "NEWRELIC_REST_API_KEY=$(NEWRELIC_REST_API_KEY)" \
		-e "NEWRELIC_APP_ID=$(NEWRELIC_APP_ID)" \
		-e "RECHARGE_BUCKET_PATH=$(RECHARGE_BUCKET_PATH)" \
		-e "RECHARGE_SERVICE_KEY=$(shell cat $(SECRETS_DIR)/$(RECHARGE_SERVICE_KEY_FILE))" \
		$(BUILD_NAMESPACE)/$(BUILD_PROJECT)/$(BUILD_IMAGE):$(REVISION_TAG)
