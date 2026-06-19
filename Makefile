.DEFAULT_GOAL := help

.PHONY: help build-npm build buildx buildx-init restart restart-build gateway/shell cli/shell shell shell-cli cleanup openclaw

BUILDX_CACHE_DIR ?= .buildx-cache
BUILDX_CACHE_NEW_DIR ?= .buildx-cache-new
BUILDX_CACHE_MODE ?= min
BUILDX_EXTRA_ARGS ?=
CACHE_FROM = $(shell if [ -f $(BUILDX_CACHE_DIR)/index.json ]; then echo "--cache-from=type=local,src=$(BUILDX_CACHE_DIR)"; fi)

ENV_FILE ?= /home/ubuntu/.openclaw/.env
OPENCLAW_CONFIG_DIR ?= $(HOME)/.openclaw
OPENCLAW_WORKSPACE_DIR ?= $(OPENCLAW_CONFIG_DIR)/workspace
COMPOSE_FILES := -f docker-compose.yml

ifneq ($(wildcard docker-compose.extra.yml),)
COMPOSE_FILES += -f docker-compose.extra.yml
endif

ifneq ($(wildcard docker-compose.local.yml),)
COMPOSE_FILES += -f docker-compose.local.yml
endif

COMPOSE := OPENCLAW_CONFIG_DIR=$(OPENCLAW_CONFIG_DIR) OPENCLAW_WORKSPACE_DIR=$(OPENCLAW_WORKSPACE_DIR) docker compose $(COMPOSE_FILES) --env-file $(ENV_FILE)
RESTART_SERVICES := openclaw-gateway openclaw-cli

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "; printf "Available targets:\n"} /^[A-Za-z0-9_\/.-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build-npm: ## Build the local project via pnpm
	pnpm build

build: buildx ## Build the local Docker image

buildx-init: ## Create or reuse the buildx builder
	@if docker buildx inspect openclaw-builder >/dev/null 2>&1; then \
		docker buildx use openclaw-builder; \
	else \
		docker buildx create --name openclaw-builder --use; \
	fi
	@docker buildx inspect --builder openclaw-builder >/dev/null

buildx: buildx-init ## Build the local Docker image with buildx
	rm -rf $(BUILDX_CACHE_NEW_DIR)
	docker buildx build \
		--builder openclaw-builder \
		--tag openclaw:local-gemini \
		--load \
		$(CACHE_FROM) $(BUILDX_EXTRA_ARGS) \
		--cache-to=type=local,dest=$(BUILDX_CACHE_NEW_DIR),mode=$(BUILDX_CACHE_MODE),ignore-error=true \
		.
	if [ -f $(BUILDX_CACHE_NEW_DIR)/index.json ]; then \
		rm -rf $(BUILDX_CACHE_DIR); \
		mv $(BUILDX_CACHE_NEW_DIR) $(BUILDX_CACHE_DIR); \
	else \
		rm -rf $(BUILDX_CACHE_NEW_DIR); \
	fi

cleanup: ## Remove build artifacts and caches to free space
	rm -rf dist/
	rm -rf $(BUILDX_CACHE_DIR)
	rm -rf $(BUILDX_CACHE_NEW_DIR)
	rm -rf .artifacts/
	rm -rf ui/dist/
	find . -name "node_modules" -type d -prune -exec rm -rf '{}' +
	find . -name "dist" -type d -prune -exec rm -rf '{}' +
	find . -name "build" -type d -prune -exec rm -rf '{}' +
	@if command -v pnpm >/dev/null 2>&1; then \
		pnpm store prune; \
	fi

restart: ## Recreate the OpenClaw containers without rebuilding
	$(COMPOSE) up -d --no-build --force-recreate $(RESTART_SERVICES)

restart-build: buildx restart ## Rebuild the image, then recreate the containers

gateway/shell: ## Open a shell in the gateway container
	$(COMPOSE) exec openclaw-gateway sh

cli/shell: ## Open a shell in the CLI container
	$(COMPOSE) exec openclaw-cli sh

shell: gateway/shell ## Alias for gateway/shell

shell-cli: cli/shell ## Alias for cli/shell

ifeq (openclaw,$(firstword $(MAKECMDGOALS)))
  OPENCLAW_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(OPENCLAW_ARGS):;@:)
endif

openclaw: ## Run the OpenClaw CLI via Docker Compose
	docker compose -f /home/ubuntu/dev/openclaw/docker-compose.yml run --rm openclaw-cli $(OPENCLAW_ARGS)

  
