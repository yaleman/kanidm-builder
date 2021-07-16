#!/usr/bin/python3

import sys
import time
import docker
from loguru import logger

VERSIONS = [
    "debian_buster",
    "opensuse_leap_152",
    "opensuse_leap_153",
    "opensuse_tumbleweed",
    "ubuntu_bionic",
    "ubuntu_focal",
    "wasm",
]

client = docker.from_env()

client_build_commands = [
    "cargo build --bin kanidm --bin kanidm_unixd --bin kanidm_unixd_status --bin kanidm_ssh_authorizedkeys --bin kanidm_ssh_authorizedkeys_direct --bin kanidm_cache_invalidate --bin kanidm_cache_clear",
    "cargo build --lib",
]

environment_data = []

for version in VERSIONS:
    version_tag = f"kanidm_{version}"
    logger.info("Building {}", version)
    image = client.images.build(
        path=".",
        dockerfile=f"Dockerfile_{version}",
        tag=version_tag,
        rm=True,
        pull=True,
        timeout=3600,
    #TODO: can we tag this with the github commit id?
    )
    for volume in client.volumes.list():
        logger.debug(volume)

    logger.info("Creating volume {}", version_tag)

    # create volume for container
    build_volume = client.volumes.create(name=version_tag,
        driver='local',
        #driver_opts={'foo': 'bar', 'baz': 'false'},
        #labels={"key": "value"},
    )
    for volume in client.volumes.list():
        logger.debug(volume)

    if client.volumes.get(version_tag):
        logger.debug("found it")
        try:
            client.volumes.get(version_tag).remove()
        except docker.errors.APIError as api_error:
            logger.error(api_error)
            sys.exit()

    logger.info("Running Client Build")
    for command in client_build_commands:
        container = client.containers.run(
            image=image,
            auto_remove=True,
            command=command,
            detach=True,
            environment=environment_data,
            volumes = { f"{version_tag}": {'bind': '/source', 'mode': 'rw'}},
        )
        while container.status == 'running':
            time.sleep(1)
