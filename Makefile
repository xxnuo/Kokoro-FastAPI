VERSION := $(shell git rev-parse --short HEAD)
UV := ~/.local/bin/uv
CURL := $(shell if command -v axel >/dev/null 2>&1; then echo "axel"; else echo "curl"; fi)
REMOTE := nvidia@gpu
REMOTE_PATH := ~/work/lzc-aipod-kokoro
DOCKER_REGISTRY := registry.lazycat.cloud/x/lzc-aipod-kokoro
DOCKER_NAME := lzc-aipod-kokoro
ENV_PROXY := http://192.168.1.200:7890

sync-from-gpu:
	rsync -arvzlt --delete --exclude-from=.rsyncignore $(REMOTE):$(REMOTE_PATH)/ ./

sync-to-gpu:
	ssh -t $(REMOTE) "mkdir -p $(REMOTE_PATH)"
	rsync -arvzlt --delete --exclude-from=.rsyncignore ./ $(REMOTE):$(REMOTE_PATH)

sync-clean:
	ssh -t $(REMOTE) "rm -rf $(REMOTE_PATH)"

prepare:
	git submodule update --init --recursive
	uv sync --all-groups
	uv pip compile --no-deps pyproject.toml -o requirements-pypi.txt

download:
	mkdir -p models
	source .venv/bin/activate && \
	MODELSCOPE_CACHE=./ \
	HF_ENDPOINT=https://hf-mirror.com \
	python3 -c "from modelscope import snapshot_download; \
		snapshot_download('iic/CosyVoice2-0.5B', local_dir='models/iic/CosyVoice2-0.5B'); \
		from wetext import Normalizer; \
		normalizer = Normalizer(); \
		print(normalizer.normalize('你好 wetext，全新版本儿，全新体验儿，简直666'))"

dev: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		export HTTP_PROXY=$(ENV_PROXY) && \
		export HTTPS_PROXY=$(ENV_PROXY) && \
		export ALL_PROXY=$(ENV_PROXY) && \
		export NO_PROXY=localhost,192.168.1.200,registry.lazycat.cloud && \
		$(UV) run python indextts/infer.py"

compile: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		export HTTP_PROXY=$(ENV_PROXY) && \
		export HTTPS_PROXY=$(ENV_PROXY) && \
		export ALL_PROXY=$(ENV_PROXY) && \
		export NO_PROXY=localhost,192.168.1.200,registry.lazycat.cloud && \
		echo $(UV) run py2so.py -d webui && \
		$(UV) pip compile --no-deps pyproject.toml -o requirements-pypi.txt"
	$(MAKE) sync-from-gpu

build: compile
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker build \
	    -f Dockerfile \
	    -t $(DOCKER_REGISTRY):$(VERSION) \
	    -t $(DOCKER_REGISTRY):latest \
        --network host \
        --build-arg "HTTP_PROXY=$(ENV_PROXY)" \
        --build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
        --build-arg "NO_PROXY=localhost,192.168.1.200,registry.lazycat.cloud" \
		."

test: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm --gpus all --name lzc-aipod-kokoro --network host -v ./output:/app/output $(DOCKER_REGISTRY):$(VERSION)"

inspect: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm --gpus all --name lzc-aipod-kokoro --network host -v ./output:/app/output $(DOCKER_REGISTRY):$(VERSION) bash"

push: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker push $(DOCKER_REGISTRY):$(VERSION) && \
		docker push $(DOCKER_REGISTRY):latest"

lzc-build:
	rm -rf content
	cd ui && pnpm run build
	mkdir -p content
	cp -r ui/dist content
	lzc-cli project build

lzc-install: lzc-build
	lzc-cli app install ./dist/

lzc-install-gpu:
	rsync -arvzlt ./ai/docker-compose.yml $(REMOTE):~/docker-compose.yml.new
	ssh -t $(REMOTE) "mkdir -p /ssd/lzc-ai-agent/services/cloud.lazycat.aipod.kokoro && \
		cd /ssd/lzc-ai-agent/services/cloud.lazycat.aipod.kokoro && \
		sudo mv ~/docker-compose.yml.new docker-compose.yml &&\
		sudo docker-compose down &&\
		sudo docker-compose up -d &&\
		sudo docker-compose logs -f"

lzc-pre-publish: lzc-build
	@echo 'lzc-cli appstore pre-publish --file changelog.md -G 9999 dist/'

.PHONY: build install lzc-build lzc-install lzc-install-gpu lzc-pre-publish sync-from-gpu sync-to-gpu sync-clean download compile test test2 push lzc-build lzc-install lzc-install-gpu lzc-pre-publish