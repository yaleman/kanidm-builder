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

MIN_CONTAINER_AGE = 3600
TIMER_LOOP_WAIT = 60
VERSIONS = [
    "debian_buster",
    "opensuse_leap_152",
    "opensuse_leap_153",
    "opensuse_tumbleweed",
    "ubuntu_bionic",  # 18.04
    "ubuntu_focal",  # 20.04
    "ubuntu_groovy",  # 20.10
    "wasm",
]

# find all the things
# find . -name Cargo.toml -exec grep -A5 -E '(bin|lib)' {} \; | grep -E '(^\[|name)' | grep -v dependencies
client_build_commands = [
    """cargo build --release \
--bin kanidm \
--bin kanidm_unixd \
--bin kanidm_unixd_status \
--bin kanidm_unixd_tasks \
--bin kanidm_ssh_authorizedkeys \
--bin kanidm_ssh_authorizedkeys_direct \
--bin kanidm_cache_invalidate \
--bin kanidm_cache_clear""",
    "cargo build --lib --release",
    "/usr/local/sbin/build_debs.sh",
]
server_build_commands = [
    """cargo build --release \
        --bin kanidmd \
        --bin kanidm_badlist_preprocess \
        --bin kanidmd_test_auth \
        --bin orca
    """,
    "cargo build --lib --release",
    "/usr/local/sbin/build_debs.sh",
]


def get_docker_client():
    """returns a docker client, just in case I want to run this remotely

    yes, premature optimization, no I don't care for your judgement.
    """
    return docker.from_env()


def get_environment_data():
    """ loads the file, does the thing"""
    if not os.path.exists(".env"):
        logger.error("Please make a .env file")
        sys.exit(1)
    with open(".env", "r") as file_handle:
        return [
            line.strip()
            for line in file_handle.readlines()
            if (not line.startswith("#") and not line.strip() == "")
        ]


def run_build_container(version_tag_str: str) -> docker.client.ContainerCollection:
    """ runs a container """
    docker_client = get_docker_client()
    logger.info("Creating container={}", version_tag_str)
    try:
        container = docker_client.containers.run(
            name=version_tag_str,
            image=version_tag_str,
            auto_remove=True,
            detach=True,
            environment=get_environment_data(),
            volumes={
                f"{version_tag_str}": {
                    "bind": "/source",
                    "mode": "rw",
                },
            },
        )
        logger.info("Starting container")
        container.start()
    except docker.errors.APIError as error_message:
        logger.error(error_message)
        sys.exit(1)
    except Exception as error_message:  # pylint: disable=broad-except
        logger.error(error_message)
        sys.exit(1)
    return container

def wait_for_container_to_finish(name: str) -> bool:
    """ does what it says on the tin """
    try:
        docker_client = get_docker_client()
        container = docker_client.containers.get(name)
    except docker.errors.NotFound:
        logger.error("Container {} not found while trying to run it, bailing because something went wrong.", name)
        sys.exit(1)
    while container.status in ("running", "created"):
        try:
            docker_client = get_docker_client()
            logger.debug(
                "Waiting for {} (state: {}) to finish running",
                name,
                container.status,
            )
            time.sleep(TIMER_LOOP_WAIT)
            container = docker_client.containers.get(name)
        except docker.errors.NotFound:
            logger.info("Container not running/created, looks to be done!")
            return True
        except docker.errors.APIError as api_error:
            logger.error(api_error)
            sys.exit(1)
    time.sleep(TIMER_LOOP_WAIT)
    logger.info("Finished waiting, carrying on.")
    return True


def build_kanidm(version: str):
    """ builds the clients """
    version_tag = f"kanidm_{version}"
    logger.info("Running client build for {}", version)
    run_build_container(version_tag)
    wait_for_container_to_finish(version_tag)



def check_if_need_to_build_image(version: str) -> bool:
    """ checks if you need to rebuild the image """
    version_tag = f"kanidm_{version}"
    docker_client = get_docker_client()
    # check if the image has recently been created
    try:
        find_client = docker_client.images.get(f"{version_tag}:latest")
    except docker.errors.ImageNotFound:
        find_client = False
    if find_client:
        create_time = (
            docker_client.images.get(f"{version_tag}:latest")
            .history()[0]
            .get("Created")
        )
        time_now = time.time()
        image_age = time_now - create_time
        logger.debug("current time: {}", time_now)
        logger.debug("create time:  {}", create_time)
        logger.debug("image age:    {}", image_age)
        if (image_age) <= MIN_CONTAINER_AGE:
            logger.info(
                "Skipping image create, image is only {} seconds old", image_age
            )
            return False
        logger.debug("Build image is {} seconds old, building.", image_age)
    else:
        logger.info("Didn't find an existing image, building.")
    return True


def build_version(version_string: str, force_container_build: bool):
    """ builds a particular version """
    client = get_docker_client()

    version_tag = f"kanidm_{version_string}"
    if not force_container_build:
        container_build = check_if_need_to_build_image(version_string)
    else:
        container_build = force_container_build

    if container_build:
        logger.info("Building container {}", version_string)
        try:
            image = client.images.build(
                path=".",
                dockerfile=f"Dockerfile_{version_string}",
                tag=version_tag,
                rm=True,
                pull=True,
                timeout=3600,
                # TODO: can we label this with the github commit id?
            )
        except docker.errors.BuildError as build_error:
            logger.error("docker.errors.BuildError for {}: {}", version_tag, build_error)
            return False
        except Exception as build_error:
            logger.error("Exception for {}: {}", version_tag, build_error)
            if 'returned a non-zero code: 104' in build_error:
                logger.error("Zypper returned 104, which means package not found.")
            return False
        logger.debug("Image: {}", image)

    try:
        old_container = client.containers.get(version_tag)
        logger.info("Killing container {}", version_tag)
        old_container.remove(force=True)
    except docker.errors.NotFound:
        logger.debug("Container {} not found, don't need to kill it!", version_tag)
    except docker.errors.APIError as api_error:
        logger.error(api_error)
        sys.exit()

    # logger.debug("Listing volumes")
    # for volume in client.volumes.list():
    #     logger.debug(volume)

    try:
        if client.volumes.get(version_tag):
            logger.debug("found existing volume for {}", version_tag)
            try:
                logger.debug("Removing volume {}", version_tag)
                client.volumes.get(version_tag).remove()
            except docker.errors.APIError as api_error:
                logger.error(api_error)
                return False
    except docker.errors.NotFound as not_found:
        logger.debug("Volume {} not found: {}", version_tag, not_found)
        logger.info("Creating volume {}", version_tag)
        # create volume for container
        try:
            create_volume = client.volumes.create(
                name=version_tag,
                driver="local",
                # driver_opts={'foo': 'bar', 'baz': 'false'},
                # labels={"key": "value"},
            )
            logger.debug("result of build volume: {}", create_volume)
        except Exception as volume_error:
            logger.error("Volume create error for {}: {}", version_tag, volume_error)
            return False
    except docker.errors.APIError as api_error:
        logger.error(api_error)
        return False

    build_kanidm(version_string)

    logger.info("Done building {}!", version_string)
    return True

@click.command()
@click.option(
    "--version",
    "-V",
    help="Specific version to build ({})".format(",".join(VERSIONS)),
)
@click.option(
    "--force-build", "-b", help="Force container build", is_flag=True, default=False
)
def run_cli(version: str, force_build: bool) -> None:
    """ does the CLI thing"""

    if not version:
        logger.info("Building all versions.")
        for version_name in VERSIONS:
            if not build_version(version_name, force_build):
                print(f"Failed to build {version_name} 😢")
    else:
        if version not in VERSIONS:
            logger.error(
                "Couldn't find {} in the available versions ({}), sorry.",
                version,
                ",".join(VERSIONS),
            )
            sys.exit(1)
        else:
            build_version(version, force_build)


if __name__ == "__main__":
    run_cli()  # pylint: disable=no-value-for-parameter
