#!/bin/bash

# builds kanidm's wasm on opensuse_tumbleweed
# designed to work on ubuntu/debian/opensuse
# James Hodgkinson 2021

RUST_VERSION="$(cat /etc/RUST_VERSION)"

PATH=/root/.cargo/bin:$PATH
export PATH

BUILD_OUTPUT_BASE='/output' # no trailing slash
OSID="Unknown"
VERSION="unknown"

if [ "$(which sccache | wc -l)" -ne 0 ]; then
    SCCACHE="$(which sccache)"
    export RUSTC_WRAPPER="${SCCACHE}"

    $SCCACHE --start-server
else
    echo "Couldn't find sccache, boo."
fi

# let's check which OS version we're on
#shellcheck disable=SC1091
source /usr/local/bin/identify_os.sh

if [ "${OSID}" == "Unknown" ]; then
    echo "Sorry, unsupported OS"
    exit 1
fi

OUTPUT="$(echo "${BUILD_OUTPUT_BASE}/${OSID}/${VERSION}/" | tr -d '"')"
echo "######################################################"

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
echo " Installing  wasm-pack"
echo "######################################################"
cargo install wasm-pack
npm install --global rollup

cd /
BUILD_DIR="/source/${OSID}/${VERSION}"
echo "######################################################"
echo " Cloning from ${SOURCE_REPO} into ${BUILD_DIR}"
echo "######################################################"

rm -rf /source/*

mkdir -p "/source/${OSID}"
mkdir -p "/buildlogs/"
BUILD_LOG="/buildlogs/$(date "+%Y-%m-%d-%H-%M-${OS}-${VERSION}").log"

git clone "${SOURCE_REPO}" "${BUILD_DIR}"

echo "Changing working dir into ${BUILD_DIR}"
cd "${BUILD_DIR}" || {
    echo "Failed to download source from ${SOURCE_REPO} bailing"
    exit 1
}
git fetch --all
mkdir -p "${BUILD_DIR}/target"

# change to the requested branch
if [ -n "${SOURCE_REPO_BRANCH}" ]; then
    echo "Listing branches"
    git branch --all
    echo "Checking out ${SOURCE_REPO_BRANCH}"
    git checkout "${SOURCE_REPO_BRANCH}"
fi

echo " ### Branches ### "
git branch -vv
echo " ### Status ### "
git status

echo "######################################################"
echo " Setup done, starting long tasks"
echo "######################################################"
if [ -n "$*" ]; then
    echo "Was requested to do a particular task, will do that"
    echo "task: ${*}"
    # shellcheck disable=SC2068
    $@

else

    echo "######################################################"
    echo " Building WASM UI"
    echo "######################################################"

    cd "${BUILD_DIR}/kanidmd_web_ui" || {
        echo "Coudln't move into ${BUILD_DIR}/kanidmd_web_ui bailing"
        exit 1
    }
    ./build_wasm.sh || {
        echo "Unable to build WASM, bailing"
        exit 1
    }


    echo "######################################################"
    echo " Compressing widget"
    echo "######################################################"

    tar czvf "${BUILD_DIR}/webui.tar.gz" pkg/*

    echo "######################################################"
    echo " Done building, copying to s3://${BUILD_ARTIFACT_BUCKET}/"
    echo "######################################################"

    # no verify ssl because docker is dumb and ipv6 is hard it seems
    echo "Copying build artifacts to s3"
    aws --endpoint-url "${S3_HOSTNAME}" \
        --no-verify-ssl \
        s3 cp \
        "${BUILD_DIR}/webui.tar.gz" \
        "s3://${BUILD_ARTIFACT_BUCKET}/" 2>&1


    echo "######################################################"
    echo " Done copying to s3://${BUILD_ARTIFACT_BUCKET}/"
    echo "######################################################"
fi