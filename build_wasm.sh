#!/bin/bash

# builds kanidm's wasm on opensuse_tumbleweed
# designed to work on ubuntu/debian/opensuse
# James Hodgkinson 2021

function failed_build_wasm {
    echo "Failed to build and install wasm-pack, bailing"
    exit 1
}

RUST_VERSION="$(cat /etc/RUST_VERSION)"

PATH=/root/.cargo/bin:$PATH
export PATH

BUILD_OUTPUT_BASE='/output' # no trailing slash
OSID="Unknown"
VERSION="unknown"

# let's check which OS version we're on
#shellcheck disable=SC1091
source /etc/profile.d/identify_os.sh

if [ "${OSID}" == "Unknown" ]; then
    echo "Sorry, unsupported OS"
    exit 1
fi

if [ "$(which sccache | wc -l)" -ne 0 ]; then
    SCCACHE="$(which sccache)"
    export RUSTC_WRAPPER="${SCCACHE}"

    $SCCACHE --start-server
    $SCCACHE -s
else
    echo "Couldn't find sccache, boo."
fi

echo "osid=\"${OSID}\" os_version=\"${VERSION}\""

OUTPUT="$(echo "${BUILD_OUTPUT_BASE}/${OSID}/${VERSION}/" | tr -d '"')"
echo "######################################################"

echo "Making output dir: ${OUTPUT}"
mkdir -p "${OUTPUT}"

# shellcheck disable=SC2086
#./os_specific/$OSID.sh

if [ -z "${SOURCE_REPO}" ]; then
    SOURCE_REPO="https://github.com/kanidm/kanidm.git"
fi

echo "######################################################"
echo " Setting rust version to ${RUST_VERSION}"
echo "######################################################"
rustup default "${RUST_VERSION}"

if [ -z "${RECOVERY_MODE}" ]; then
    echo "######################################################"
    echo " Installing  wasm-pack"
    echo "######################################################"
    RUST_BACKTRACE=full cargo install wasm-pack || failed_build_wasm
    echo "######################################################"
    echo " Installing  npm packages"
    echo "######################################################"
    npm install --global rollup || failed_build_wasm
fi

cd /
BUILD_DIR="/source/${OSID}/${VERSION}"


echo "######################################################"
echo " Cloning from ${SOURCE_REPO} into ${BUILD_DIR}"
echo "######################################################"

rm -rf /source/*

mkdir -p "/source/${OSID}"
mkdir -p "/buildlogs/"
BUILD_LOG="/buildlogs/$(date "+%Y-%m-%d-%H-%M-${OSID}-${VERSION}").log"

git clone "${SOURCE_REPO}" "${BUILD_DIR}" | tee -a "${BUILD_LOG}"

echo "Changing working dir into ${BUILD_DIR}" | tee -a "${BUILD_LOG}"
cd "${BUILD_DIR}" || {
    echo "Failed to download source from ${SOURCE_REPO} bailing" | tee -a "${BUILD_LOG}"
    exit 1
}
git fetch --all | tee -a "${BUILD_LOG}"
mkdir -p "${BUILD_DIR}/target"

# change to the requested branch
if [ -n "${SOURCE_REPO_BRANCH}" ]; then
    echo "Listing branches" | tee -a "${BUILD_LOG}"
    git branch --all | tee -a "${BUILD_LOG}"
    echo "Checking out ${SOURCE_REPO_BRANCH}" | tee -a "${BUILD_LOG}"
    git checkout "${SOURCE_REPO_BRANCH}" | tee -a "${BUILD_LOG}"
fi

echo " ### Branches ### " | tee -a "${BUILD_LOG}"
git branch -vv | tee -a "${BUILD_LOG}"
echo " ### Status ### " | tee -a "${BUILD_LOG}"
git status | tee -a "${BUILD_LOG}"

echo "######################################################"
echo " Setup done, starting long tasks" | tee -a "${BUILD_LOG}"
echo "######################################################"
if [ -n "$*" ]; then
    echo "Was requested to do a particular task, will do that" | tee -a "${BUILD_LOG}"
    echo "task: ${*}" | tee -a "${BUILD_LOG}"
    # shellcheck disable=SC2068
    $@

else

    echo "######################################################"
    echo " Building WASM UI" | tee -a "${BUILD_LOG}"
    echo "######################################################"

    cd "${BUILD_DIR}/kanidmd_web_ui" || {
        echo "Coudln't move into ${BUILD_DIR}/kanidmd_web_ui bailing" | tee -a "${BUILD_LOG}"
        exit 1
    }
    ./build_wasm.sh || {
        echo "Unable to build WASM, bailing" | tee -a "${BUILD_LOG}"
        exit 1
    }


    echo "######################################################"
    echo " Compressing widget" | tee -a "${BUILD_LOG}"
    echo "######################################################"

    tar czvf "${BUILD_DIR}/webui.tar.gz" pkg/* | tee -a "${BUILD_LOG}"

    echo "######################################################"
    echo " Done building, copying to s3://${BUILD_ARTIFACT_BUCKET}/" | tee -a "${BUILD_LOG}"
    echo "######################################################"

    # no verify ssl because docker is dumb and ipv6 is hard it seems
    echo "Copying build artifacts to s3"
    aws --endpoint-url "${S3_HOSTNAME}"  --no-progress --no-verify-ssl s3 cp "${BUILD_DIR}/webui.tar.gz" "s3://${BUILD_ARTIFACT_BUCKET}/"

    echo "######################################################"
    echo " Done copying to s3://${BUILD_ARTIFACT_BUCKET}/"
    echo "######################################################"
fi