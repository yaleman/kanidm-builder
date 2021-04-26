#!/bin/bash

# builds kanidm on the local architecture
# designed to work on ubuntu/debian/opensuse
# James Hodgkinson 2021

echo "######################################################"
echo " Starting build script"
echo "######################################################"

PATH=/root/.cargo/bin:$PATH
export PATH

BUILD_OUTPUT_BASE='/output' # no trailing slash
OSID="Unknown"
VERSION="unknown"

# let's check which OS version we're on
# shellcheck disable=SC1091
source /etc/profile.d/identify_os.sh

if [ "${OSID}" == "Unknown" ]; then
    echo "Sorry, unsupported OS"
    exit 1
fi

if [ -z "${SOURCE_REPO}" ]; then
    SOURCE_REPO="https://github.com/kanidm/kanidm.git"
fi

if [ "$(which sccache | wc -l)" -ne 0 ]; then

    echo "######################################################"
    echo " Starting sccache"
    echo "######################################################"
    SCCACHE="$(which sccache)"
    export RUSTC_WRAPPER="${SCCACHE}"

    $SCCACHE --start-server
    $SCCACHE -s
else
    echo "######################################################"
    echo " Couldn't find sccache, boo."
    echo "######################################################"
fi

OUTPUT="$(echo "${BUILD_OUTPUT_BASE}/${OSID}/${VERSION}/" | tr -d '"')"
echo "######################################################"
echo "Making output dir: ${OUTPUT}"
echo "######################################################"
mkdir -p "${OUTPUT}"

RUST_VERSION="$(cat /etc/RUST_VERSION)"
echo "######################################################"
echo " Setting rust version to ${RUST_VERSION}"
echo "######################################################"
rustup default "${RUST_VERSION}"

cd /
BUILD_DIR="/source/${OSID}/${VERSION}"
echo "######################################################"
echo " Cloning from ${SOURCE_REPO} into ${BUILD_DIR}"
echo "######################################################"

rm -rf /source/*

mkdir -p "/source/${OSID}"
mkdir -p "/buildlogs/"
BUILD_LOG="/buildlogs/$(date "+%Y-%m-%d-%H-%M")-${OS}-${VERSION}.log"

git clone "${SOURCE_REPO}" "${BUILD_DIR}"

echo "Changing working dir into ${BUILD_DIR}"
cd "${BUILD_DIR}" || {
    echo "Failed to download source from ${SOURCE_REPO} bailing"
    exit 1
}

git fetch --all
echo "making target dir ${BUILD_DIR}/target"
mkdir -p "${BUILD_DIR}/target"

# change to the requested branch
if [ -n "${SOURCE_REPO_BRANCH}" ]; then
    echo "######################################################"
    echo "Config specifies to use ${SOURCE_REPO_BRANCH}"
    echo "######################################################"
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
    echo " Skipping tests due to #416."
    echo "######################################################"
    # echo "######################################################"
    # echo "Doing default thing, running tests."
    # echo "######################################################"
    # RUST_BACKTRACE=1 cargo test --release || {
    #     echo "Failed to pass tests, not doing build/copy stage"
    #     exit 1
    # }
    echo "######################################################"
    echo " Doing build stage"
    echo "######################################################"
    cargo build --workspace --bins --release || {
        echo "unable to build, bailing"
        exit 1
    }

    echo "######################################################"
    echo " Done building, copying to s3://${BUILD_ARTIFACT_BUCKET}/${OSID}/${VERSION}"
    echo "######################################################"


    mkdir -p "$HOME/.aws/"
    cat > "$HOME/.aws/config" <<-EOF
[default]
region=us-east-1
output=json
EOF

    cat > "$HOME/.aws/credentials" <<-EOF
[default]
region=us-east-1

EOF
    rm -rf "${BUILD_DIR}/target/release/build"
    rm -rf "${BUILD_DIR}/target/release/deps"
    rm -rf "${BUILD_DIR}/target/release/examples"
    rm -rf "${BUILD_DIR}/target/release/incremental"
    rm -rf "${BUILD_DIR}/target/release/*.dSYM"
    rm -rf "${BUILD_DIR}/target/release/.fingerprint"


    export AWS_DEFAULT_PROFILE=default
    echo "Setting default signature to v4"
    aws configure set s3.signature_version s3v4
    echo "Setting output json"
    aws configure set output json

    S3_SOURCE="${BUILD_DIR}/target/release/"
    S3_DESTINATION="s3://${BUILD_ARTIFACT_BUCKET}/${OSID}/${VERSION}/$(uname -m)/"

    echo "Listing files in release dir:"
    find "${S3_SOURCE}" -maxdepth 1 | tee -a "${BUILD_LOG}"

    echo "Copying build artifacts to s3 (source=${S3_SOURCE} destination=${S3_DESTINATION})"
    # no verify ssl because docker is dumb and ipv6 is hard it seems
    aws --debug --endpoint-url "${S3_HOSTNAME}" \
        --no-verify-ssl \
        s3 sync "${S3_SOURCE}" "${S3_DESTINATION}"

    echo "Copying build logs to s3"
    aws --endpoint-url "${S3_HOSTNAME}" \
        --no-verify-ssl \
        s3 sync \
        "/buildlogs/" \
        "s3://${BUILD_ARTIFACT_BUCKET}/logs/" 2>&1 | grep -v InsecureRequestWarning

fi
