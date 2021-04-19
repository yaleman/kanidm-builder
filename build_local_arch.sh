#!/bin/bash

# builds kanidm on the local architecture
# designed to work on ubuntu/debian/opensuse
# James Hodgkinson 2021


RUST_VERSION="$(cat /etc/RUST_VERSION)"

PATH=/root/.cargo/bin:$PATH
export PATH

BUILD_OUTPUT_BASE='/output' # no trailing slash
OSID="Unknown"

if [ "$(which sccache | wc -l)" -ne 0 ]; then
    SCCACHE="$(which sccache)"
    export RUSTC_WRAPPER="${SCCACHE}"

    $SCCACHE --start-server
else
    echo "Couldn't find sccache, output from 'which sccache' was:"
    which -a sccache
fi

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
echo " Setting rust version to ${RUST_VERSION}"
echo "######################################################"
rustup default "${RUST_VERSION}"

echo "######################################################"
echo " Cloning from ${SOURCE_REPO}"
echo "######################################################"
rm -rf /source/

git clone --depth=1 "${SOURCE_REPO}" /source/

cd /source/ || {
    echo "Failed to download source from ${SOURCE_REPO} bailing"
    exit 1
}

if [ -n "${SOURCE_REPO_BRANCH}" ]; then
    git checkout -b "${SOURCE_REPO_BRANCH}"
    git pull origin "${SOURCE_REPO_BRANCH}"
fi

git status

# echo "######################################################"
# echo " Building kanidm_unix_int"
# echo "######################################################"
# cd kanidm_unix_int || {
#     echo "Failed to cd into kanidm_unix_int, bailing"
#     exit 1
# }

if [ -n "$*" ]; then
    echo "Was requested to do a particular task, will do that"
    echo "task: ${*}"
    # shellcheck disable=SC2068
    $@

else
    echo "Doing default thing, building."
    cargo test --release --workspace || {
        echo "Failed to pass tests, not doing build/copy stage"
        exit 1
    }
    cargo build --release || exit 1

    cp -R /source/target/release/* "${OUTPUT}"
fi
