.PHONY: help all build  debian_buster build_debian_buster release_debian_buster client_debian_buster opensuse_leap_152 build_opensuse_leap_152 release_opensuse_leap_152 client_opensuse_leap_152 opensuse_leap_153 build_opensuse_leap_153 release_opensuse_leap_153 client_opensuse_leap_153 opensuse_tumbleweed build_opensuse_tumbleweed release_opensuse_tumbleweed client_opensuse_tumbleweed ubuntu_bionic build_ubuntu_bionic release_ubuntu_bionic client_ubuntu_bionic ubuntu_focal build_ubuntu_focal release_ubuntu_focal client_ubuntu_focal wasm build_wasm release_wasm client_wasm
help:
	@echo "Possible make options:"
	@bash -c "grep -E '^\S+\:' Makefile | grep -vE '^\.' | awk '{print $$1}'"

all: build release


debian_buster: build_debian_buster release_debian_buster
build_debian_buster:
	docker build -t kanidm_build_debian_buster . -f Dockerfile_debian_buster

client_debian_buster:
	@-docker volume rm kanidm_build_debian_buster ||:
	docker volume create kanidm_build_debian_buster
	docker run --detach --rm --env-file .env --volume "kanidm_build_debian_buster:/source" --name kanidm_build_debian_buster kanidm_build_debian_buster 'cargo build --bin kanidm --bin kanidm_unixd --bin kanidm_unixd_status --bin kanidm_ssh_authorizedkeys --bin kanidm_ssh_authorizedkeys_direct --bin kanidm_cache_invalidate --bin kanidm_cache_clear'
	docker logs -f kanidm_build_debian_buster
	docker run --detach --rm --env-file .env --volume "kanidm_build_debian_buster:/source" --name kanidm_build_debian_buster kanidm_build_debian_buster 'cargo build --lib'
	docker logs -f kanidm_build_debian_buster

release_debian_buster:
	@-docker volume rm kanidm_build_debian_buster ||:
	docker volume create kanidm_build_debian_buster
	docker run --detach --rm --env-file .env --volume "kanidm_build_debian_buster:/source" --name kanidm_build_debian_buster kanidm_build_debian_buster
	docker logs -f kanidm_build_debian_buster


opensuse_leap_152: build_opensuse_leap_152 release_opensuse_leap_152
build_opensuse_leap_152:
	docker build -t kanidm_build_opensuse_leap_152 . -f Dockerfile_opensuse_leap_152

client_opensuse_leap_152:
	@-docker volume rm kanidm_build_opensuse_leap_152 ||:
	docker volume create kanidm_build_opensuse_leap_152
	docker run --detach --rm --env-file .env --volume "kanidm_build_opensuse_leap_152:/source" --name kanidm_build_opensuse_leap_152 kanidm_build_opensuse_leap_152 'cargo build --bin kanidm --bin kanidm_unixd --bin kanidm_unixd_status --bin kanidm_ssh_authorizedkeys --bin kanidm_ssh_authorizedkeys_direct --bin kanidm_cache_invalidate --bin kanidm_cache_clear'
	docker logs -f kanidm_build_opensuse_leap_152
	docker run --detach --rm --env-file .env --volume "kanidm_build_opensuse_leap_152:/source" --name kanidm_build_opensuse_leap_152 kanidm_build_opensuse_leap_152 'cargo build --lib'
	docker logs -f kanidm_build_opensuse_leap_152

release_opensuse_leap_152:
	@-docker volume rm kanidm_build_opensuse_leap_152 ||:
	docker volume create kanidm_build_opensuse_leap_152
	docker run --detach --rm --env-file .env --volume "kanidm_build_opensuse_leap_152:/source" --name kanidm_build_opensuse_leap_152 kanidm_build_opensuse_leap_152
	docker logs -f kanidm_build_opensuse_leap_152


opensuse_leap_153: build_opensuse_leap_153 release_opensuse_leap_153
build_opensuse_leap_153:
	docker build -t kanidm_build_opensuse_leap_153 . -f Dockerfile_opensuse_leap_153

client_opensuse_leap_153:
	@-docker volume rm kanidm_build_opensuse_leap_153 ||:
	docker volume create kanidm_build_opensuse_leap_153
	docker run --detach --rm --env-file .env --volume "kanidm_build_opensuse_leap_153:/source" --name kanidm_build_opensuse_leap_153 kanidm_build_opensuse_leap_153 'cargo build --bin kanidm --bin kanidm_unixd --bin kanidm_unixd_status --bin kanidm_ssh_authorizedkeys --bin kanidm_ssh_authorizedkeys_direct --bin kanidm_cache_invalidate --bin kanidm_cache_clear'
	docker logs -f kanidm_build_opensuse_leap_153
	docker run --detach --rm --env-file .env --volume "kanidm_build_opensuse_leap_153:/source" --name kanidm_build_opensuse_leap_153 kanidm_build_opensuse_leap_153 'cargo build --lib'
	docker logs -f kanidm_build_opensuse_leap_153

release_opensuse_leap_153:
	@-docker volume rm kanidm_build_opensuse_leap_153 ||:
	docker volume create kanidm_build_opensuse_leap_153
	docker run --detach --rm --env-file .env --volume "kanidm_build_opensuse_leap_153:/source" --name kanidm_build_opensuse_leap_153 kanidm_build_opensuse_leap_153
	docker logs -f kanidm_build_opensuse_leap_153


opensuse_tumbleweed: build_opensuse_tumbleweed release_opensuse_tumbleweed
build_opensuse_tumbleweed:
	docker build -t kanidm_build_opensuse_tumbleweed . -f Dockerfile_opensuse_tumbleweed

client_opensuse_tumbleweed:
	@-docker volume rm kanidm_build_opensuse_tumbleweed ||:
	docker volume create kanidm_build_opensuse_tumbleweed
	docker run --detach --rm --env-file .env --volume "kanidm_build_opensuse_tumbleweed:/source" --name kanidm_build_opensuse_tumbleweed kanidm_build_opensuse_tumbleweed 'cargo build --bin kanidm --bin kanidm_unixd --bin kanidm_unixd_status --bin kanidm_ssh_authorizedkeys --bin kanidm_ssh_authorizedkeys_direct --bin kanidm_cache_invalidate --bin kanidm_cache_clear'
	docker logs -f kanidm_build_opensuse_tumbleweed
	docker run --detach --rm --env-file .env --volume "kanidm_build_opensuse_tumbleweed:/source" --name kanidm_build_opensuse_tumbleweed kanidm_build_opensuse_tumbleweed 'cargo build --lib'
	docker logs -f kanidm_build_opensuse_tumbleweed

release_opensuse_tumbleweed:
	@-docker volume rm kanidm_build_opensuse_tumbleweed ||:
	docker volume create kanidm_build_opensuse_tumbleweed
	docker run --detach --rm --env-file .env --volume "kanidm_build_opensuse_tumbleweed:/source" --name kanidm_build_opensuse_tumbleweed kanidm_build_opensuse_tumbleweed
	docker logs -f kanidm_build_opensuse_tumbleweed


ubuntu_bionic: build_ubuntu_bionic release_ubuntu_bionic
build_ubuntu_bionic:
	docker build -t kanidm_build_ubuntu_bionic . -f Dockerfile_ubuntu_bionic

client_ubuntu_bionic:
	@-docker volume rm kanidm_build_ubuntu_bionic ||:
	docker volume create kanidm_build_ubuntu_bionic
	docker run --detach --rm --env-file .env --volume "kanidm_build_ubuntu_bionic:/source" --name kanidm_build_ubuntu_bionic kanidm_build_ubuntu_bionic 'cargo build --bin kanidm --bin kanidm_unixd --bin kanidm_unixd_status --bin kanidm_ssh_authorizedkeys --bin kanidm_ssh_authorizedkeys_direct --bin kanidm_cache_invalidate --bin kanidm_cache_clear'
	docker logs -f kanidm_build_ubuntu_bionic
	docker run --detach --rm --env-file .env --volume "kanidm_build_ubuntu_bionic:/source" --name kanidm_build_ubuntu_bionic kanidm_build_ubuntu_bionic 'cargo build --lib'
	docker logs -f kanidm_build_ubuntu_bionic

release_ubuntu_bionic:
	@-docker volume rm kanidm_build_ubuntu_bionic ||:
	docker volume create kanidm_build_ubuntu_bionic
	docker run --detach --rm --env-file .env --volume "kanidm_build_ubuntu_bionic:/source" --name kanidm_build_ubuntu_bionic kanidm_build_ubuntu_bionic
	docker logs -f kanidm_build_ubuntu_bionic


ubuntu_focal: build_ubuntu_focal release_ubuntu_focal
build_ubuntu_focal:
	docker build -t kanidm_build_ubuntu_focal . -f Dockerfile_ubuntu_focal

client_ubuntu_focal:
	@-docker volume rm kanidm_build_ubuntu_focal ||:
	docker volume create kanidm_build_ubuntu_focal
	docker run --detach --rm --env-file .env --volume "kanidm_build_ubuntu_focal:/source" --name kanidm_build_ubuntu_focal kanidm_build_ubuntu_focal 'cargo build --bin kanidm --bin kanidm_unixd --bin kanidm_unixd_status --bin kanidm_ssh_authorizedkeys --bin kanidm_ssh_authorizedkeys_direct --bin kanidm_cache_invalidate --bin kanidm_cache_clear'
	docker logs -f kanidm_build_ubuntu_focal
	docker run --detach --rm --env-file .env --volume "kanidm_build_ubuntu_focal:/source" --name kanidm_build_ubuntu_focal kanidm_build_ubuntu_focal 'cargo build --lib'
	docker logs -f kanidm_build_ubuntu_focal

release_ubuntu_focal:
	@-docker volume rm kanidm_build_ubuntu_focal ||:
	docker volume create kanidm_build_ubuntu_focal
	docker run --detach --rm --env-file .env --volume "kanidm_build_ubuntu_focal:/source" --name kanidm_build_ubuntu_focal kanidm_build_ubuntu_focal
	docker logs -f kanidm_build_ubuntu_focal


wasm: build_wasm release_wasm
build_wasm:
	docker build -t kanidm_build_wasm . -f Dockerfile_wasm

release_wasm:
	@-docker volume rm kanidm_build_wasm ||:
	docker volume create kanidm_build_wasm
	docker run --detach --rm --env-file .env --volume "kanidm_build_wasm:/source" --name kanidm_build_wasm kanidm_build_wasm
	docker logs -f kanidm_build_wasm


