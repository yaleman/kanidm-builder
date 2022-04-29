#!/usr/bin/env python3

"""
builds kanidm images with docker and a spoon full of nightmares

"""

import os.path
from pathlib import Path
import sys
import time
from typing import Dict, List, Optional

import click
import docker # type: ignore
import docker.errors # type: ignore
from loguru import logger

MIN_CONTAINER_AGE = 3600
TIMER_LOOP_WAIT = 60
VERSIONS = [
    # "opensuse_leap_152",
    # "opensuse_leap_153",
    # "opensuse_tumbleweed",
    "ubuntu_bionic",  # 18.04
    "ubuntu_focal",  # 20.04
    "ubuntu_groovy",  # 20.10
    "ubuntu_hirsute",  # 21
    "ubuntu_impish", # 21.10
    "ubuntu_jammy",
    # "wasm",
    "debian_buster",
    "debian_bullseye"
]

for filename in os.listdir("."):
    if filename.startswith("Dockerfile_"):
        if filename.endswith("_generic"):
            logger.debug("Skipping {} as it's a generic", filename)
            continue
        logger.debug("Found file: {}", filename)
        version_name = filename.replace("Dockerfile_", "")
        if version_name not in VERSIONS:
            logger.debug("Adding version: {}", version_name)
            VERSIONS.append(version_name)

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


def get_docker_client() -> docker.DockerClient:
    """returns a docker client, just in case I want to run this remotely

    yes, premature optimization, no I don't care for your judgement.
    """
    return docker.from_env()


def get_environment_data() -> List[str]:
    """ loads the file, does the thing"""
    envfile = Path(".env")
    if not envfile.exists():
        logger.error("Please make a .env file")
        sys.exit(1)
    with envfile.open(encoding="utf8") as file_handle:
        environment = [
            line.strip()
            for line in file_handle.readlines()
            if (not line.startswith("#") and not line.strip() == "")
        ]
        # logger.debug("environment:\n{}", environment)
        return environment


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
            network_mode="host",
            volumes={
                f"{version_tag_str}": {
                    "bind": "/source",
                    "mode": "rw",
                },
            },
        )
        logger.info("Starting kandim build container...")
        container.start()
        logger.info("Started build container for version_tag_str={} id={}", version_tag_str, container.short_id)
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
        container_id = container.short_id
    except docker.errors.NotFound:
        logger.error("Container {} not found while trying to run it, bailing because something went wrong.", name)
        sys.exit(1)
    while container.status in ("running", "created"):
        try:
            docker_client = get_docker_client()
            logger.debug(
                "container_name={} id={} state={}",
                name,
                container_id,
                container.status,
            )
            time.sleep(TIMER_LOOP_WAIT)
            container = docker_client.containers.get(name)
        except docker.errors.NotFound:
            logger.info("container_name={} state=not_found looks to be done!", name)
            return True
        except docker.errors.APIError as api_error:
            logger.error("API Error while waiting for container_name={} id={} error='{}'", name, container_id, api_error)
            sys.exit(1)
    time.sleep(TIMER_LOOP_WAIT)
    logger.info("state=finished container_name={} id={}", name, container_id)
    return True


def build_kanidm(version: str) -> None:
    """ builds the clients """
    version_tag = f"kanidm_{version}"
    logger.info("Running client build for version_tag={}", version)
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

def remove_volume(
    name: str
    ) -> bool:
    """ removes a python volume, returns bool about result """
    client = docker.APIClient()
    try:
        logger.debug("Removing volume: {}", name)
        client.remove_volume(name)
        return True
    except docker.errors.NotFound as error:
        logger.debug("Couldn't find volume to remove {}: {}", name, error)
        return False


def try_get_generic(version_string: str, buildargs: Dict[str, str]) -> str:
    """ if you can't find the real one, try a generic """
    os_ver = version_string.split("_")[0]
    generic_dockerfile = Path(f"Dockerfile_{os_ver}_generic")
    if generic_dockerfile.exists():
        buildargs['DISTRO'] = "_".join(version_string.split("_")[1:])
        return str(generic_dockerfile)
    logger.error("Couldn't find Dockerfile for {}, tried {} and {}",
                    version_string,
                    generic_dockerfile,
                    )
    sys.exit(1)

def cleanup_before_build(
    client: docker.DockerClient,
    version_tag: str,
    keep_volume: bool,
    ) -> None:
    """ removes the old volume/container  if not needed """
    try:
        old_container = client.containers.get(version_tag)
        logger.info("Killing container {}", version_tag)
        old_container.remove(force=True)

        if not keep_volume:
            remove_volume(version_tag)
    except docker.errors.NotFound:
        logger.debug("Container {} not found, don't need to kill it!", version_tag)
    except docker.errors.APIError as api_error:
        logger.error(api_error)
        sys.exit()
    finally:
        if not keep_volume:
            remove_volume(version_tag)
    try:
        if client.volumes.get(version_tag):
            logger.debug("found existing volume for {}", version_tag)
            remove_volume(version_tag)
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
            logger.debug("result of build volume: {}", getattr(create_volume, "name", str(create_volume)))
        except Exception as volume_error: #pylint: disable=broad-except
            logger.error("Volume create error for {}: {}", version_tag, volume_error)
            sys.exit(1)
    except docker.errors.APIError as api_error:
        logger.error(api_error)
        sys.exit(1)

# pylint: disable=too-many-locals,too-many-branches,too-many-statements
def build_version(
    version_string: str,
    force_build: bool,
    keep_volume: bool,
    just_build_image: bool,
    ) -> bool:
    """ builds a particular version """
    client = get_docker_client()

    version_tag = f"kanidm_{version_string}"
    container_build = check_if_need_to_build_image(version_string) if not force_build else force_build

    dockerfile = Path(f"Dockerfile_{version_string}")
    buildargs: Dict[str, str] = {}
    if not dockerfile.exists():
        dockerfile = Path(try_get_generic(version_string, buildargs))

    if container_build:
        logger.info("Building container_name={}", version_string)
        try:
            image = client.images.build(
                path=".",
                dockerfile=dockerfile.name,
                tag=version_tag,
                rm=True,
                pull=True,
                timeout=3600,
                buildargs=buildargs,
                # TODO: can we label this with the github commit id?
            )
        except docker.errors.BuildError as build_error:
            logger.error("docker.errors.BuildError for {}: {}", version_tag, build_error)
            if 'returned a non-zero code: 104' in f"{build_error}":
                logger.error("Zypper returned 104, which means package not found.")
            if 'returned a non-zero code: 139' in f"{build_error}":
                logger.error("Zypper returned 139, which means glibc has blown up.")
            if not keep_volume:
                remove_volume(version_string)
            return False

        except Exception as build_error: #pylint: disable=broad-except
            logger.error("Exception for {}: {}", version_tag, build_error)
            if not keep_volume:
                remove_volume(version_tag)
            return False
        logger.debug("Image: {}", image)

    if just_build_image:
        return True

    cleanup_before_build(client, version_tag, keep_volume)
    build_kanidm(version_string)

    if not keep_volume:
        remove_volume(version_tag)
    logger.info("Done building {}!", version_string)
    return True

@click.command()
@click.option(
    "--version",
    "-V",
    help=f"Specific version to build ({','.join(VERSIONS)})",
)
@click.option(
    "--keep-volume", "-k", help="Keep the volume after building - for debugging etc", is_flag=True, default=False
)
@click.option(
    "--force-build", "-b", help="Force container build", is_flag=True, default=False
)
@click.option(
    "--just-build-image", "-j", is_flag=True, default=False, help="Only build the docker image"
)
def run_cli(
    version: Optional[str] = None,
    force_build: bool =False,
    keep_volume: bool = False,
    just_build_image: bool=False,
    ) -> None:
    """ does the CLI thing"""



    if not version:
        versions_to_build = VERSIONS
        logger.info("Building all versions.")
        # for version_to_build in VERSIONS:
        #     if not build_version(
        #         version_to_build,
        #         force_build,
        #         keep_volume,
        #         ):
        #         logger.error("Failed to build {} 😢", version_to_build)
    else:
        if version not in VERSIONS:
            logger.error(
                "Couldn't find {} in the available versions ({}), sorry.",
                version,
                ",".join(VERSIONS),
            )
            sys.exit(1)
        versions_to_build = [version]

    for version in versions_to_build:
        if not build_version(
            version,
            force_build,
            keep_volume,
            just_build_image,
        ):
            logger.error("Failed to build {}", version)


if __name__ == "__main__":
    run_cli()  # pylint: disable=no-value-for-parameter
