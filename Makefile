DART ?= dart
FLUTTER ?= flutter
DOCKER ?= docker
HELM ?= helm
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
# Optional, Make-compatible KEY=value settings; command-line overrides still win.
ENV_FILE ?= $(ROOT)/.env
-include $(ENV_FILE)

REGISTRY ?=
SERVER_IMAGE ?= tw-server
SERVER_IMAGE_TAG ?= local
SERVER_PLATFORM ?=
SERVER_IMAGE_REF = $(if $(strip $(REGISTRY)),$(REGISTRY)/)$(SERVER_IMAGE):$(SERVER_IMAGE_TAG)

WEB_IMAGE ?= tw-web
WEB_IMAGE_TAG ?= local
WEB_PLATFORM ?= $(SERVER_PLATFORM)
WEB_IMAGE_REF = $(if $(strip $(REGISTRY)),$(REGISTRY)/)$(WEB_IMAGE):$(WEB_IMAGE_TAG)

KUBE_CONTEXT ?=
KUBE_NAMESPACE ?= tw
SERVER_RELEASE ?= api
WEB_RELEASE ?= web
WEB_VALUES_FILE ?=
INGRESS_RELEASE ?= edge
INGRESS_VALUES_FILE ?=
SERVER_VALUES_FILE ?=

COMPOSE = $(DOCKER) compose -f "$(ROOT)/server/docker-compose.yml"

.DEFAULT_GOAL := help

.PHONY: help test test-app test-shared test-server \
        analyze analyze-app analyze-shared analyze-server \
        format format-app format-shared format-server \
        format-check format-check-app format-check-shared format-check-server \
        db-start db-stop build-server push-server check-registry deploy-server deploy-ingress \
        build-web build-local-web push-web deploy-web check-server-registry

help:
	@printf '%s\n' \
	  'make test          Run app, shared, and server tests (requires the database)' \
	  'make analyze       Run dart analyze in every package' \
	  'make format        Format every package' \
	  'make format-check  Check formatting without modifying files' \
	  'Append -app, -shared, or -server to select one package.' \
	  'make db-start      Start PostgreSQL and wait for readiness' \
	  'make db-stop       Stop and remove the database containers' \
	  'make build-server  Build the server image using optional root .env settings' \
	  'make push-server   Build and push the server image (requires REGISTRY)' \
	  'make deploy-server Deploy the server using a local Helm values file' \
	  'make deploy-ingress Deploy ingress using a local Helm values file' \
	  'make build-web     Build the Flutter web image using optional root .env settings' \
	  'make build-local-web Build the web image for the local Compose stack' \
	  'make push-web      Build and push the web image (requires REGISTRY)' \
	  'make deploy-web    Deploy the web app using a local Helm values file'

test: test-app test-shared test-server

test-app:
	cd "$(ROOT)/app" && $(FLUTTER) test

test-shared:
	@if [ -d "$(ROOT)/shared/test" ]; then \
	  cd "$(ROOT)/shared" && $(DART) test; \
	else \
	  echo 'shared: no tests directory; skipping.'; \
	fi

test-server:
	cd "$(ROOT)/server" && $(DART) test

analyze: analyze-app analyze-shared analyze-server

analyze-app analyze-shared analyze-server:
	cd "$(ROOT)/$(patsubst analyze-%,%,$@)" && $(DART) analyze

format: format-app format-shared format-server

format-app format-shared format-server:
	cd "$(ROOT)/$(patsubst format-%,%,$@)" && $(DART) format .

format-check: format-check-app format-check-shared format-check-server

format-check-app format-check-shared format-check-server:
	cd "$(ROOT)/$(patsubst format-check-%,%,$@)" && $(DART) format --output=none --set-exit-if-changed .

db-start:
	$(COMPOSE) up -d --wait --wait-timeout 90 postgres

db-stop:
	$(COMPOSE) down

build-server:
	$(DOCKER) build $(if $(strip $(SERVER_PLATFORM)),--platform "$(SERVER_PLATFORM)") -f "$(ROOT)/server/Dockerfile" -t "$(SERVER_IMAGE_REF)" "$(ROOT)"

# Validate before building, including when invoked with make -j.
push-server: check-server-registry
	"$(MAKE)" build-server
	$(DOCKER) push "$(SERVER_IMAGE_REF)"

check-server-registry: check-registry

check-registry:
	@test -n "$(strip $(REGISTRY))" || { echo 'Set REGISTRY in .env or pass REGISTRY=host:port to make.' >&2; exit 1; }

define deploy-chart
	@test -n "$(strip $(KUBE_CONTEXT))" || { echo 'Set KUBE_CONTEXT in .env or on the make command line.' >&2; exit 1; }
	@test -n "$(strip $($(3)))" || { echo 'Set $(3) to a local Helm values file.' >&2; exit 1; }
	@test -r "$($(3))" || { echo '$(3) must point to a readable file.' >&2; exit 1; }
	$(HELM) --kube-context "$(KUBE_CONTEXT)" upgrade --install "$(1)" "$(ROOT)/$(2)" \
	  --namespace "$(KUBE_NAMESPACE)" \
	  --values "$($(3))" \
	  --wait --timeout 5m
endef

deploy-server:
	$(call deploy-chart,$(SERVER_RELEASE),server/helm/server,SERVER_VALUES_FILE)

deploy-ingress:
	$(call deploy-chart,$(INGRESS_RELEASE),helm/ingress,INGRESS_VALUES_FILE)

build-web:
	cd "$(ROOT)/app" && $(FLUTTER) build web --release $(WEB_BUILD_FLAGS)
	$(DOCKER) build $(if $(strip $(WEB_PLATFORM)),--platform "$(WEB_PLATFORM)") -f "$(ROOT)/app/Dockerfile" -t "$(WEB_IMAGE_REF)" "$(ROOT)"

build-local-web:
	"$(MAKE)" build-web REGISTRY= WEB_IMAGE=tw-web WEB_IMAGE_TAG=compose-local WEB_PLATFORM= \
	  WEB_BUILD_FLAGS="--dart-define=API_URL=http://localhost:8080/api/v0 --no-web-resources-cdn"

push-web: check-registry
	"$(MAKE)" build-web
	$(DOCKER) push "$(WEB_IMAGE_REF)"

deploy-web:
	$(call deploy-chart,$(WEB_RELEASE),app/helm/web,WEB_VALUES_FILE)
