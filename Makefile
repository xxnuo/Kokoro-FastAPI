.PHONY: build download install lzc-build lzc-install lzc-install-gpu lzc-pre-publish push sync-clean sync-from-gpu sync-to-gpu test

VERSION := $(shell git rev-parse --short HEAD)
UV := ~/.local/bin/uv
CURL := $(shell if command -v axel >/dev/null 2>&1; then echo "axel"; else echo "curl"; fi)
REMOTE := nvidia@gpu
REMOTE_PATH := ~/projects/work/lzc-aipod-tts
DOCKER_REGISTRY := registry.lazycat.cloud/x/lzc-aipod-tts
DOCKER_NAME := lzc-aipod-tts
ENV_PROXY := http://wa.lan:7890
ENV_NOPROXY := localhost,wa.lan,lzc-pod-APhKhy.lan,registry.lazycat.cloud,127.0.0.1

sync-from-gpu:
	rsync -arvzlt --delete --exclude-from=.rsyncignore $(REMOTE):$(REMOTE_PATH)/ ./

sync-to-gpu:
	ssh -t $(REMOTE) "mkdir -p $(REMOTE_PATH)"
	rsync -arvzlt --delete --exclude-from=.rsyncignore ./ $(REMOTE):$(REMOTE_PATH)

sync-clean:
	ssh -t $(REMOTE) "rm -rf $(REMOTE_PATH)"

download:
	git lfs install
	if [ ! -d "Kokoro-82M-v1.1-zh" ]; then \
		git clone https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh; \
	else \
		cd Kokoro-82M-v1.1-zh && git pull; \
	fi
	if [ ! -d "Kokoro-82M" ]; then \
		git clone https://huggingface.co/hexgrad/Kokoro-82M; \
	else \
		cd Kokoro-82M && git pull; \
	fi

prepare:
	mkdir -p api/src/voices/v1_1-zh
	cp Kokoro-82M-v1.1-zh/voices/*.pt api/src/voices/v1_1-zh/
	cp Kokoro-82M/voices/*.pt api/src/voices/v1_1-zh/
	mkdir -p api/src/models/v1_1-zh
	cp Kokoro-82M-v1.1-zh/kokoro-v1_1-zh.pth api/src/models/v1_1-zh/kokoro-v1_1-zh.pth
	cp Kokoro-82M-v1.1-zh/config.json api/src/models/v1_1-zh/config.json

build: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker build \
		--progress=plain \
		-f docker/gpu/Dockerfile \
		-t $(DOCKER_REGISTRY):$(VERSION) \
		-t $(DOCKER_REGISTRY):latest \
		--network host \
		--build-arg "HTTP_PROXY=$(ENV_PROXY)" \
		--build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
		--build-arg "ALL_PROXY=$(ENV_PROXY)" \
		--build-arg "NO_PROXY=$(ENV_NOPROXY)" \
		--shm-size=8g \
		."

build-ui-arm: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker build \
		-f ui/Dockerfile \
		-t $(DOCKER_REGISTRY)-ui-arm:$(VERSION) \
		-t $(DOCKER_REGISTRY)-ui-arm:latest \
		--network host \
		--build-arg "HTTP_PROXY=$(ENV_PROXY)" \
		--build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
		--build-arg "NO_PROXY=$(ENV_NOPROXY)" \
		."

build-ui-amd:
	docker build \
		-f ui/Dockerfile \
		-t $(DOCKER_REGISTRY)-ui-amd:$(VERSION) \
		-t $(DOCKER_REGISTRY)-ui-amd:latest \
		--network host \
		--build-arg "HTTP_PROXY=$(ENV_PROXY)" \
		--build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
		--build-arg "NO_PROXY=$(ENV_NOPROXY)" \
		.

test: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm \
		--gpus all \
		--name $(DOCKER_NAME) \
		--network host \
		--shm-size=8g \
		$(DOCKER_REGISTRY):$(VERSION)"

inspect: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm \
		--gpus all \
		--name $(DOCKER_NAME) \
		--network host \
		--shm-size=8g \
		$(DOCKER_REGISTRY):$(VERSION) bash"

push: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker push $(DOCKER_REGISTRY):$(VERSION) && \
		echo docker push $(DOCKER_REGISTRY):latest"

push-ui-arm: build-ui-arm
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker push $(DOCKER_REGISTRY)-ui-arm:$(VERSION) && \
		echo docker push $(DOCKER_REGISTRY)-ui-arm:latest"

push-ui-amd: build-ui-amd
	docker push $(DOCKER_REGISTRY)-ui-amd:$(VERSION) && \
	echo docker push $(DOCKER_REGISTRY)-ui-amd:latest"

lzc-build:
	mkdir -p dist
	lzc-cli project build

lzc-install: lzc-build
	lzc-cli app install ./dist/

lzc-install-gpu:
	rsync -arvzlt ./ai/docker-compose.yml $(REMOTE):~/docker-compose.yml.new
	ssh -t $(REMOTE) "mkdir -p /ssd/lzc-ai-agent/services/cloud.lazycat.aipod.tts && \
		cd /ssd/lzc-ai-agent/services/cloud.lazycat.aipod.tts && \
		sudo mv ~/docker-compose.yml.new docker-compose.yml && \
		sudo docker-compose up -d && \
		sudo docker-compose logs -f"

lzc-pre-publish: lzc-build
	@echo 'lzc-cli appstore pre-publish --file changelog.md -G 9999 dist/'
