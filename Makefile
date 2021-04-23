.PHONY: help build/kanidmd build/radiusd test/kanidmd push/kanidmd push/radiusd vendor-prep doc install-tools prep vendor

IMAGE_BASE ?= kanidm
IMAGE_VERSION ?= release
EXT_OPTS ?=
#IMAGE_ARCH ?= "linux/amd64,linux/arm64"
#ARGS ?= --build-arg "SCCACHE_REDIS=redis://172.24.20.4:6379"
DOCKER_OPTIONS ?=  --env-file .env

.DEFAULT: help
help:
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##/\n\t/'
	@echo "help file coming soon"

all: build release

build: build_ubuntu_bionic build_debian_buster build_opensuse_tumbleweed build_opensuse_leap_152

build_ubuntu_bionic:
	docker build -t kanidm_build_ubuntu_bionic . -f Dockerfile_ubuntu_bionic

build_debian_buster:
	docker build -t kanidm_build_debian_buster . -f Dockerfile_debian_buster

build_opensuse_tumbleweed:
	docker build -t kanidm_build_opensuse_tumbleweed . -f Dockerfile_opensuse_tumbleweed

build_opensuse_leap_152:
	docker build -t kanidm_build_opensuse_leap152 . -f Dockerfile_opensuse_leap152

release: release_ubuntu_bionic release_debian_buster release_opensuse_tumbleweed release_opensuse_leap152

release_ubuntu_bionic:
	docker run --detach --rm $(DOCKER_OPTIONS) --name kanidm_build_ubuntu_bionic kanidm_build_ubuntu_bionic
	docker logs -f --name kanidm_build_ubuntu_bionic
release_debian_buster:
	docker run --detach --rm $(DOCKER_OPTIONS) --name kanidm_build_debian_buster kanidm_build_debian_buster
	docker logs -f --name kanidm_build_debian_buster
release_opensuse_tumbleweed:
	docker run --detach --rm $(DOCKER_OPTIONS) --name kanidm_build_opensuse_tumbleweed kanidm_build_opensuse_tumbleweed
	docker logs -f --name kanidm_build_opensuse_tumbleweed
release_opensuse_leap152:
	docker run --detach --rm $(DOCKER_OPTIONS) --name kanidm_build_opensuse_leap152 kanidm_build_opensuse_leap152
	docker logs -f --name kanidm_build_opensuse_leap152

# roll up all the builds
debian_buster: build_debian_buster release_debian_buster
ubuntu_bionic: build_ubuntu_bionic release_ubuntu_bionic
opensuse_leap_152: build_opensuse_leap_152 release_opensuse_leap152
opensuse_tumbleweed: build_opensuse_tumbleweed release_opensuse_tumbleweed