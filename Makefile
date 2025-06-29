VERSION := $(shell git rev-parse --short HEAD)
UV := ~/.local/bin/uv
CURL := $(shell if command -v axel >/dev/null 2>&1; then echo "axel"; else echo "curl"; fi)
REMOTE := nvidia@gpu
REMOTE_PATH := ~/projects/work/lzc-aipod-kokoro
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

download:
	git lfs install
	cd api/src/models && \
	git clone https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh && \
	mv Kokoro-82M-v1.1-zh v1_1-zh && \
	cp -r v1_1-zh/voices ../voices/v1_1-zh


prepare: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		sudo apt-get install nvidia-container-toolkit"

build: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker build \
	    -f docker/gpu/Dockerfile \
	    -t $(DOCKER_REGISTRY):$(VERSION) \
	    -t $(DOCKER_REGISTRY):latest \
        --network host \
        --build-arg "HTTP_PROXY=$(ENV_PROXY)" \
        --build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
        --build-arg "NO_PROXY=localhost,192.168.1.200,registry.lazycat.cloud" \
		--shm-size=8g \
		--volume /tmp/argus_socket:/tmp/argus_socket --volume /etc/enctune.conf:/etc/enctune.conf \
		--volume /etc/nv_tegra_release:/etc/nv_tegra_release --volume /tmp/nv_jetson_model:/tmp/nv_jetson_model \
		--volume /var/run/dbus:/var/run/dbus --volume /var/run/avahi-daemon/socket:/var/run/avahi-daemon/socket \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		-v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro \
		--device /dev/snd -e PULSE_SERVER=unix:/run/user/1000/pulse/native -v /run/user/1000/pulse:/run/user/1000/pulse \
		--device /dev/bus/usb --device /dev/i2c-0 --device /dev/i2c-1 --device /dev/i2c-2 --device /dev/i2c-3 --device /dev/i2c-4 \
		--device /dev/i2c-5 --device /dev/i2c-6 --device /dev/i2c-7 --device /dev/i2c-8 -v /run/jtop.sock:/run/jtop.sock \
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
        --build-arg "NO_PROXY=localhost,192.168.1.200,registry.lazycat.cloud" \
		."

build-ui-amd:
	docker build \
	    -f ui/Dockerfile \
	    -t $(DOCKER_REGISTRY)-ui-amd:$(VERSION) \
	    -t $(DOCKER_REGISTRY)-ui-amd:latest \
        --network host \
        --build-arg "HTTP_PROXY=$(ENV_PROXY)" \
        --build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
        --build-arg "NO_PROXY=localhost,192.168.1.200,registry.lazycat.cloud" \
		.

test: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm \
		--gpus all \
		--name lzc-aipod-kokoro \
		--network host \
		--shm-size=8g \
		--volume /tmp/argus_socket:/tmp/argus_socket --volume /etc/enctune.conf:/etc/enctune.conf \
		--volume /etc/nv_tegra_release:/etc/nv_tegra_release --volume /tmp/nv_jetson_model:/tmp/nv_jetson_model \
		--volume /var/run/dbus:/var/run/dbus --volume /var/run/avahi-daemon/socket:/var/run/avahi-daemon/socket \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		-v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro \
		--device /dev/snd -e PULSE_SERVER=unix:/run/user/1000/pulse/native -v /run/user/1000/pulse:/run/user/1000/pulse \
		--device /dev/bus/usb --device /dev/i2c-0 --device /dev/i2c-1 --device /dev/i2c-2 --device /dev/i2c-3 --device /dev/i2c-4 \
		--device /dev/i2c-5 --device /dev/i2c-6 --device /dev/i2c-7 --device /dev/i2c-8 -v /run/jtop.sock:/run/jtop.sock \
		$(DOCKER_REGISTRY):$(VERSION)"

inspect: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm \
		--gpus all \
		--name lzc-aipod-kokoro \
		--network host \
		--shm-size=8g \
		--volume /tmp/argus_socket:/tmp/argus_socket --volume /etc/enctune.conf:/etc/enctune.conf \
		--volume /etc/nv_tegra_release:/etc/nv_tegra_release --volume /tmp/nv_jetson_model:/tmp/nv_jetson_model \
		--volume /var/run/dbus:/var/run/dbus --volume /var/run/avahi-daemon/socket:/var/run/avahi-daemon/socket \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		-v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro \
		--device /dev/snd -e PULSE_SERVER=unix:/run/user/1000/pulse/native -v /run/user/1000/pulse:/run/user/1000/pulse \
		--device /dev/bus/usb --device /dev/i2c-0 --device /dev/i2c-1 --device /dev/i2c-2 --device /dev/i2c-3 --device /dev/i2c-4 \
		--device /dev/i2c-5 --device /dev/i2c-6 --device /dev/i2c-7 --device /dev/i2c-8 -v /run/jtop.sock:/run/jtop.sock \
		$(DOCKER_REGISTRY):$(VERSION) bash"

push: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker push $(DOCKER_REGISTRY):$(VERSION) && \
		docker push $(DOCKER_REGISTRY):latest"

push-ui-arm: build-ui-arm
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker push $(DOCKER_REGISTRY)-ui-arm:$(VERSION) && \
		docker push $(DOCKER_REGISTRY)-ui-arm:latest"

push-ui-amd: build-ui-amd
	docker push $(DOCKER_REGISTRY)-ui-amd:$(VERSION) && \
	docker push $(DOCKER_REGISTRY)-ui-amd:latest

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

.PHONY: build install lzc-build lzc-install lzc-install-gpu lzc-pre-publish sync-from-gpu sync-to-gpu sync-clean download test push lzc-build lzc-install lzc-install-gpu lzc-pre-publish