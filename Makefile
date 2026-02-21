.PHONY: build buildx buildx-init

build: buildx

buildx-init:
	docker buildx create --use --name openclaw-builder || docker buildx use openclaw-builder

buildx: buildx-init
	docker buildx build \
		--tag openclaw:local-gemini \
		--load \
		--cache-from=type=local,src=.buildx-cache \
		--cache-to=type=local,dest=.buildx-cache,mode=max \
		.
