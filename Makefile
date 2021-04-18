.PHONY: help build/kanidmd build/radiusd test/kanidmd push/kanidmd push/radiusd vendor-prep doc install-tools prep vendor

IMAGE_BASE ?= kanidm
IMAGE_VERSION ?= devel
EXT_OPTS ?=
IMAGE_ARCH ?= "linux/amd64,linux/arm64"
ARGS ?= --build-arg "SCCACHE_REDIS=redis://172.24.20.4:6379"

.DEFAULT: help
help:
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##/\n\t/'