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
    build_image = True
    version_tag = f"kanidm_{version}"
    # check if the image has recently been created
    if client.images.get(f'{version_tag}:latest'):
        create_time = client.images.get(f'{version_tag}:latest').history()[0].get('Created')
        if (time.time() - create_time) <= 60*20:
            logger.info("Skipping image create, image is only {} seconds old", time.time() - create_time)
            build_image = False
    if build_image:
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


    if client.containers.get(version_tag):
        logger.info("Killing container {}", version_tag)
        client.containers.get(version_tag).remove(force=True)

    logger.debug("Listing volumes")
    for volume in client.volumes.list():
        logger.debug(volume)

    if client.volumes.get(version_tag):
        logger.debug("found it")
        try:
            logger.debug("Removing tag")
            client.volumes.get(version_tag).remove()
        except docker.errors.APIError as api_error:
            logger.error(api_error)
            sys.exit()

    logger.info("Creating volume {}", version_tag)
    # create volume for container
    build_volume = client.volumes.create(name=version_tag,
        driver='local',
        #driver_opts={'foo': 'bar', 'baz': 'false'},
        #labels={"key": "value"},
    )
    logger.info("Running client build for {}", version)
    for command in client_build_commands:
        container = client.containers.run(
            name=version_tag,
            image=version_tag,
            auto_remove=True,
            command=command,
            detach=True,
            environment=environment_data,
            volumes = { f"{version_tag}": {'bind': '/source', 'mode': 'rw'}},
        )
        while container.status == 'running':
            logger.debug("Waiting for {} to run {}", version_tag, command)
            time.sleep(1)
        logger.info(container.logs())
    logger.info("Done!")
    sys.exit()