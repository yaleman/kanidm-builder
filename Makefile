.PHONY: help all build build_ubuntu_bionic build_debian_buster build_opensuse_tumbleweed build_opensuse_leap_152 release release_ubuntu_bionic release_debian_buster release_opensuse_tumbleweed release_opensuse_leap152 debian_buster ubuntu_bionic opensuse_leap_152 opensuse_tumbleweed clean wasm build_wasm release_wasm

IMAGE_BASE ?= kanidm
IMAGE_VERSION ?= release
EXT_OPTS ?=
#IMAGE_ARCH ?= "linux/amd64,linux/arm64"
#ARGS ?= --build-arg "SCCACHE_REDIS=redis://172.24.20.4:6379"
DOCKER_OPTIONS ?= --detach --rm --env-file .env

.DEFAULT: help

help:
	@echo "Possible make options:"
	@bash -c "grep -E '^\S+\:' Makefile | grep -vE '^\.' | awk '{print $$1}'"

all: build release

build: build_ubuntu_bionic build_debian_buster build_opensuse_tumbleweed build_opensuse_leap_152 build_wasm

build_ubuntu_bionic:
	docker build -t kanidm_build_ubuntu_bionic . -f Dockerfile_ubuntu_bionic

build_debian_buster:
	docker build -t kanidm_build_debian_buster . -f Dockerfile_debian_buster

build_opensuse_tumbleweed:
	docker build -t kanidm_build_opensuse_tumbleweed . -f Dockerfile_opensuse_tumbleweed

build_opensuse_leap_152:
	docker build -t kanidm_build_opensuse_leap152 . -f Dockerfile_opensuse_leap152

build_wasm:
	docker build -t kanidm_build_wasm . -f Dockerfile_wasm

release: release_ubuntu_bionic release_debian_buster release_opensuse_tumbleweed release_opensuse_leap152 release_wasm

release_ubuntu_bionic:
	@-docker volume rm kanidm_build_ubuntu_bionic ||:
	docker volume create kanidm_build_ubuntu_bionic
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_ubuntu_bionic:/source"  --name kanidm_build_ubuntu_bionic kanidm_build_ubuntu_bionic
	docker logs -f kanidm_build_ubuntu_bionic
	@-docker volume rm kanidm_build_ubuntu_bionic ||:
release_debian_buster:
	@-docker volume rm kanidm_build_debian_buster ||:
	docker volume create kanidm_build_debian_buster
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_debian_buster:/source" --name kanidm_build_debian_buster kanidm_build_debian_buster
	docker logs -f kanidm_build_debian_buster
	@-docker volume rm kanidm_build_debian_buster ||:
release_opensuse_tumbleweed:
	@-docker volume rm kanidm_build_opensuse_tumbleweed ||:
	docker volume create kanidm_build_opensuse_tumbleweed
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_opensuse_tumbleweed:/source" --name kanidm_build_opensuse_tumbleweed kanidm_build_opensuse_tumbleweed
	docker logs -f kanidm_build_opensuse_tumbleweed
	@-docker volume rm kanidm_build_opensuse_tumbleweed ||:

release_opensuse_leap152:
	@-docker volume rm kanidm_build_opensuse_leap152 ||:
	docker volume create kanidm_build_opensuse_leap152
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_opensuse_leap152:/source" --name kanidm_build_opensuse_leap152 kanidm_build_opensuse_leap152
	docker logs -f kanidm_build_opensuse_leap152
	@-docker volume rm kanidm_build_opensuse_leap152 ||:

release_wasm:
	@-docker volume rm kanidm_build_wasm ||:
	docker volume create kanidm_build_wasm
	docker run $(DOCKER_OPTIONS) --volume "kanidm_build_wasm:/source" --name kanidm_build_wasm kanidm_build_wasm
	docker logs -f kanidm_build_wasm
	@-docker volume rm kanidm_build_wasm ||:



# roll up all the builds
debian_buster: build_debian_buster release_debian_buster
ubuntu_bionic: build_ubuntu_bionic release_ubuntu_bionic
opensuse_leap_152: build_opensuse_leap_152 release_opensuse_leap152
opensuse_tumbleweed: build_opensuse_tumbleweed release_opensuse_tumbleweed
wasm: build_wasm release_wasm
