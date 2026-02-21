.PHONY: build buildx buildx-init restart

CACHE_FROM := $(shell if [ -f .buildx-cache/index.json ]; then echo "--cache-from=type=local,src=.buildx-cache"; fi)

build: buildx

buildx-init:
	docker buildx create --use --name openclaw-builder || docker buildx use openclaw-builder

buildx: buildx-init
	docker buildx build \
		--tag openclaw:local-gemini \
		--load \
		$(CACHE_FROM) \
		--cache-to=type=local,dest=.buildx-cache,mode=max \
		.

restart:
	docker compose down
	docker compose up -d --build
