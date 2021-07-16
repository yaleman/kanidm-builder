#!/usr/bin/python3

""" makefile-maker

makes... makefiles.

"""

BUILD_CLIENTS= [
    # "cargo test --workspace",
    "cargo build --bin kanidm --bin kanidm_unixd --bin kanidm_unixd_status --bin kanidm_ssh_authorizedkeys --bin kanidm_ssh_authorizedkeys_direct --bin kanidm_cache_invalidate --bin kanidm_cache_clear",
    "cargo build --lib",
]

DOCKER_OPTIONS = "--detach --rm --env-file .env"
IMAGE_BASE = "kanidm"
IMAGE_VERSION = "release"
VERSIONS = [
    "debian_buster",
    "opensuse_leap_152",
    "opensuse_leap_153",
    "opensuse_tumbleweed",
    "ubuntu_bionic",
    "ubuntu_focal",
    "ubuntu_groovy",
    "wasm",
]

def add_version(makefile: str, version_name: str, has_client: bool = True):
    """"
    does a thing
    """
    makefile += f"""
{version_name}: build_{version_name} release_{version_name}
build_{version_name}:
	docker build -t kanidm_build_{version_name} . -f Dockerfile_{version_name}
"""
    if has_client:
        makefile += f"""
client_{version_name}:
	@-docker volume rm kanidm_build_{version_name} ||:
	docker volume create kanidm_build_{version_name}
"""


        for client_command in BUILD_CLIENTS:
            makefile += f"\tdocker run {DOCKER_OPTIONS} --volume \"kanidm_build_{version_name}:/source\" --name kanidm_build_{version_name} kanidm_build_{version_name} '{client_command}'\n"
            makefile += f"\tdocker logs -f kanidm_build_{version_name}\n"

        # end if has_client
    makefile += f"""
release_{version_name}:
	@-docker volume rm kanidm_build_{version_name} ||:
	docker volume create kanidm_build_{version_name}
	docker run {DOCKER_OPTIONS} --volume "kanidm_build_{version_name}:/source" --name kanidm_build_{version_name} kanidm_build_{version_name}
	docker logs -f kanidm_build_{version_name}

"""
    return makefile


new_makefile = open('makefile_template.txt', 'r').read()
for version in VERSIONS:
    if version == 'wasm':
        new_makefile = add_version(new_makefile, version, False)
    else:
        new_makefile = add_version(new_makefile, version)


# add the .PHONY line at the top
phony_line = ".PHONY: help all build "
for version in VERSIONS:
    phony_line += f" {version} build_{version} release_{version} client_{version}"

new_makefile = f"{phony_line}\n{new_makefile}"
print(new_makefile)