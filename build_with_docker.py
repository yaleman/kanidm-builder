#!/usr/bin/env python3

"""
builds kanidm images with docker and a spoon full of nightmares

"""

import os.path
import sys
import time

import click
import docker
from loguru import logger

VERSIONS = [
    "debian_buster",
    "opensuse_leap_152",
    "opensuse_leap_153",
    "opensuse_tumbleweed",
    "ubuntu_bionic", # 18.04
    "ubuntu_focal",  # 20.04
    "ubuntu_groovy", # 20.10
    "wasm",
]


client_build_commands = [
    "cargo build --bin kanidm --bin kanidm_unixd --bin kanidm_unixd_status --bin kanidm_ssh_authorizedkeys --bin kanidm_ssh_authorizedkeys_direct --bin kanidm_cache_invalidate --bin kanidm_cache_clear", #pylint: disable=line-too-long
    "cargo build --lib",
]

def get_docker_client():
    """ returns a docker client, just in case I want to run this remotely

    yes, premature optimization, no I don't care for your judgement.
    """
    return docker.from_env()

def get_environment_data():
    """ loads the file, does the thing"""
    if not os.path.exists('.env'):
        logger.error("Please make a .env file")
        sys.exit(1)
    with open('.env','r') as file_handle:
        return [ line.strip() for line in file_handle.readlines() if (not line.startswith('#') and not line.strip() == '')]

def build_clients(version: str):
    """ builds the clients """
    docker_client = get_docker_client()
    version_tag = f"kanidm_{version}"
    logger.info("Running client build for {}", version)
    for command in client_build_commands:
        try:
            container = docker_client.containers.run(
                name=version_tag,
                image=version_tag,
                auto_remove=True,
                command=command,
                detach=True,
                environment=get_environment_data(),
                volumes = { f"{version_tag}": {'bind': '/source', 'mode': 'rw'}},
            )
            container.start()
        except docker.errors.APIError as error_message:
            logger.error(error_message)
            sys.exit(1)
        except Exception as error_message: #pylint: disable=broad-except
            logger.error(error_message)
            sys.exit(1)

        while container.status in ('running', 'created'):
            logger.debug("Waiting for {} (state: {}) to run {}", version_tag, container.status, command)
            logger.debug(container.stats())
            time.sleep(5)
        logger.info(container.status)
        time.sleep(5)
        logger.info(container.logs())

def check_if_need_to_build_image(version: str) -> bool:
    """ checks if you need to rebuild the image """
    version_tag = f"kanidm_{version}"
    docker_client = get_docker_client()
    # check if the image has recently been created
    if docker_client.images.get(f'{version_tag}:latest'):
        create_time = docker_client.images.get(f'{version_tag}:latest').history()[0].get('Created')
        time_now = time.time()
        image_age = time_now - create_time
        logger.debug("current time: {}", time_now)
        logger.debug("create time:  {}", create_time)
        logger.debug("image age:    {}", image_age)
        if (image_age) <= (60*20):
            logger.info("Skipping image create, image is only {} seconds old", image_age)
            return False
        logger.debug("Build image is {} seconds old, building.", image_age)
    else:
        logger.info("Didn't find an existing image, building.")
    return True

def build_server(version_string: str) -> bool:
    """ does the server build thing """
    raise NotImplementedError


def build_version(version_string: str, client_only: bool=False):
    """ builds a particular version """
    client = get_docker_client()

    version_tag = f"kanidm_{version_string}"
    if check_if_need_to_build_image(version_string):
        logger.info("Building {}", version_string)
        image = client.images.build(
            path=".",
            dockerfile=f"Dockerfile_{version_string}",
            tag=version_tag,
            rm=True,
            pull=True,
            timeout=3600,
        #TODO: can we label this with the github commit id?
        )
        logger.debug("Image: {}", image)

    try:
        old_container = client.containers.get(version_tag)
        logger.info("Killing container {}", version_tag)
        old_container.remove(force=True)
    except docker.errors.NotFound:
        logger.debug("Container {} not found, don't need to kill it!", version_tag)

    # logger.debug("Listing volumes")
    # for volume in client.volumes.list():
    #     logger.debug(volume)

    if client.volumes.get(version_tag):
        logger.debug("found existing volume for {}", version_tag)
        try:
            logger.debug("Removing volume {}", version_tag)
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
    logger.debug("result of build volume: {}", build_volume)

    build_clients(version_string)
    if not client_only:
        try:
            build_server(version_string)
        except NotImplementedError:
            logger.warning("Not actually building the server yet... :)")

    logger.info("Done!")
    sys.exit()

@click.command()
@click.option('--version', '-V',
              help='Specific version to build ({})'.format(','.join(VERSIONS)),
)
@click.option('--client-only', '-c',
              help='Build only the clients',
              type=bool,
              default=False
)
def run_cli(version: str, client_only: bool) -> None:
    """ does the CLI thing"""
    if not version:
        for version_name in VERSIONS:
            build_version(version_name, client_only)
    else:
        if version not in VERSIONS:
            logger.error("Couldn't find {} in the available versions ({}), sorry.", version, ','.join(VERSIONS))
            sys.exit(1)
        else:
            build_version(version, client_only)


if __name__ == '__main__':
    run_cli() #pylint: disable=no-value-for-parameter
