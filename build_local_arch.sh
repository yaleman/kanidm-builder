#!/bin/bash

# builds kanidm on the local architecture
# designed to work on ubuntu/debian/opensuse
# James Hodgkinson 2021

PATH=/root/.cargo/bin:$PATH
export PATH

BUILD_OUTPUT_BASE='/output' # no trailing slash
OSID="Unknown"

# let's see if we're on suse
if [ -f /etc/os-release ]; then
    if [ "$(grep -ci suse /etc/os-release)" -gt 0 ]; then
        OSID="$(grep -E '^ID=' /etc/os-release | awk -F'=' '{print $2}')"
        VERSION="$(grep -E '^VERSION=' /etc/os-release | awk -F'=' '{print $2}')"
    fi
    if [ "$(grep -ciE '^ID=debian' /etc/os-release)" -gt 0 ]; then
        OSID="$(grep -E '^ID=' /etc/os-release | awk -F'=' '{print $2}' )"
        VERSION="$(grep -E '^VERSION_CODENAME=' /etc/os-release | awk -F'=' '{print $2}')"
    fi
    if [ "$(grep -ciE '^ID=ubuntu' /etc/os-release)" -gt 0 ]; then
        OSID="$(grep -E '^ID=' /etc/os-release | awk -F'=' '{print $2}' )"
        VERSION="$(grep -E '^VERSION_CODENAME=' /etc/os-release | awk -F'=' '{print $2}')"

    fi
fi

if [ "${OSID}" == "Unknown" ]; then
    echo "Sorry, unsupported OS"
    exit 1
fi

OUTPUT="$(echo "${BUILD_OUTPUT_BASE}/${OSID}/${VERSION}/" | tr -d '"')"
echo "Making output dir: ${OUTPUT}"
mkdir -p "${OUTPUT}"

echo "Running OS-specific things"
# shellcheck disable=SC2086
#./os_specific/$OSID.sh

if [ -z "${SOURCE_REPO}" ]; then
    SOURCE_REPO="https://github.com/kanidm/kanidm.git"
fi
echo "######################################################"
echo " Updating rust"
echo "######################################################"
rustup default 1.49.0

echo "######################################################"
echo " Cloning from ${SOURCE_REPO}"
echo "######################################################"
git clone "${SOURCE_REPO}" /source/

cd /source/ || {
    echo "Failed to download source from ${SOURCE_REPO} bailing"
    exit 1
}

echo "######################################################"
echo " Building kanidm_unix_int"
echo "######################################################"
cd kanidm_unix_int || {
    echo "Failed to cd into kanidm_unix_int, bailing"
    exit 1
}
cargo build --release --message-format=json
copy -R /source/target/release/* "${OUTPUT}"
