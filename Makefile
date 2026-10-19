DART ?= dart
FLUTTER ?= flutter
DOCKER ?= docker
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
COMPOSE = $(DOCKER) compose -f "$(ROOT)/server/docker-compose.yml"

.DEFAULT_GOAL := help

.PHONY: help test test-app test-shared test-server \
        analyze analyze-app analyze-shared analyze-server \
        format format-app format-shared format-server \
        format-check format-check-app format-check-shared format-check-server \
        db-start db-stop

help:
	@printf '%s\n' \
	  'make test          Run app, shared, and server tests (requires the database)' \
	  'make analyze       Run dart analyze in every package' \
	  'make format        Format every package' \
	  'make format-check  Check formatting without modifying files' \
	  'Append -app, -shared, or -server to select one package.' \
	  'make db-start      Start PostgreSQL and wait for readiness' \
	  'make db-stop       Stop and remove the database containers'

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
	cd "$(ROOT)/server" && $(DART) test --concurrency=1

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
