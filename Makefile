.PHONY: help all build build_ubuntu_bionic build_debian_buster build_opensuse_tumbleweed build_opensuse_leap_152 release release_ubuntu_bionic release_debian_buster release_opensuse_tumbleweed release_opensuse_leap152 debian_buster ubuntu_bionic opensuse_leap_152 opensuse_tumbleweed clean wasm build_wasm release_wasm opensuse_leap_153 build_opensuse_leap_153 release_opensuse_leap153 clients_debian_buster

IMAGE_BASE ?= kanidm
IMAGE_VERSION ?= release
EXT_OPTS ?=
#IMAGE_ARCH ?= "linux/amd64,linux/arm64"
#ARGS ?= --build-arg "SCCACHE_REDIS=redis://172.24.20.4:6379"
DOCKER_OPTIONS ?= --detach --rm --env-file .env
BUILD_CLIENTS ?= "cargo test --workspace && cargo build --bin kanidm --bin kanidm_unixd --bin kanidm_unixd_status --bin kanidm_ssh_authorizedkeys --bin kanidm_ssh_authorizedkeys_direct --bin kanidm_cache_invalidate --bin kanidm_cache_clear && cargo build --lib"

.DEFAULT: help

help:
	@echo "Possible make options:"
	@bash -c "grep -E '^\S+\:' Makefile | grep -vE '^\.' | awk '{print $$1}'"

all: build release

build: build_ubuntu_bionic build_ubuntu_focal build_debian_buster build_opensuse_tumbleweed build_opensuse_leap_152 build_opensuse_leap_153 build_wasm
release: release_ubuntu_bionic release_debian_buster release_opensuse_tumbleweed release_opensuse_leap152 release_opensuse_leap153 release_wasm

debian_buster: build_debian_buster release_debian_buster
build_debian_buster:
	docker build -t kanidm_build_debian_buster . -f Dockerfile_debian_buster
clients_debian_buster:
	@-docker volume rm kanidm_build_debian_buster ||:
	docker volume create kanidm_build_debian_buster
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_debian_buster:/source" --name kanidm_build_debian_buster kanidm_build_debian_buster $(BUILD_CLIENTS)
	docker logs -f kanidm_build_debian_buster
release_debian_buster:
	@-docker volume rm kanidm_build_debian_buster ||:
	docker volume create kanidm_build_debian_buster
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_debian_buster:/source" --name kanidm_build_debian_buster kanidm_build_debian_buster
	docker logs -f kanidm_build_debian_buster

opensuse_leap_152: build_opensuse_leap_152 release_opensuse_leap152
build_opensuse_leap_152:
	docker build -t kanidm_build_opensuse_leap152 . -f Dockerfile_opensuse_leap152
release_opensuse_leap152:
	@-docker volume rm kanidm_build_opensuse_leap152 ||:
	docker volume create kanidm_build_opensuse_leap152
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_opensuse_leap152:/source" --name kanidm_build_opensuse_leap152 kanidm_build_opensuse_leap152
	docker logs -f kanidm_build_opensuse_leap152

opensuse_leap_153: build_opensuse_leap_153 release_opensuse_leap153
build_opensuse_leap_153:
	docker build -t kanidm_build_opensuse_leap153 . -f Dockerfile_opensuse_leap153
release_opensuse_leap153:
	@-docker volume rm kanidm_build_opensuse_leap153 ||:
	docker volume create kanidm_build_opensuse_leap153
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_opensuse_leap153:/source" --name kanidm_build_opensuse_leap153 kanidm_build_opensuse_leap153
	docker logs -f kanidm_build_opensuse_leap153

opensuse_tumbleweed: build_opensuse_tumbleweed release_opensuse_tumbleweed
build_opensuse_tumbleweed:
	docker build -t kanidm_build_opensuse_tumbleweed . -f Dockerfile_opensuse_tumbleweed
release_opensuse_tumbleweed:
	@-docker volume rm kanidm_build_opensuse_tumbleweed ||:
	docker volume create kanidm_build_opensuse_tumbleweed
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_opensuse_tumbleweed:/source" --name kanidm_build_opensuse_tumbleweed kanidm_build_opensuse_tumbleweed
	docker logs -f kanidm_build_opensuse_tumbleweed


ubuntu_bionic: build_ubuntu_bionic release_ubuntu_bionic
build_ubuntu_bionic:
	docker build -t kanidm_build_ubuntu_bionic . -f Dockerfile_ubuntu_bionic
release_ubuntu_bionic:
	@-docker volume rm kanidm_build_ubuntu_bionic ||:
	docker volume create kanidm_build_ubuntu_bionic
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_ubuntu_bionic:/source"  --name kanidm_build_ubuntu_bionic kanidm_build_ubuntu_bionic
	docker logs -f kanidm_build_ubuntu_bionic

ubuntu_focal: build_ubuntu_focal release_ubuntu_focal
build_ubuntu_focal:
	docker build -t kanidm_build_ubuntu_focal . -f Dockerfile_ubuntu_focal
release_ubuntu_focal:
	@-docker volume rm kanidm_build_ubuntu_focal ||:
	docker volume create kanidm_build_ubuntu_focal
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_ubuntu_focal:/source"  --name kanidm_build_ubuntu_focal kanidm_build_ubuntu_focal
	docker logs -f kanidm_build_ubuntu_focal

wasm: build_wasm release_wasm
build_wasm:
	docker build -t kanidm_build_wasm . -f Dockerfile_wasm
release_wasm:
	@-docker volume rm kanidm_build_wasm ||:
	docker volume create kanidm_build_wasm
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_wasm:/source" --name kanidm_build_wasm kanidm_build_wasm
	docker logs -f kanidm_build_wasm
