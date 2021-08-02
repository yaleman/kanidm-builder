#!/bin/bash

# builds kanidm on the local architecture
# designed to work on ubuntu/debian/opensuse
# James Hodgkinson 2021

function upload_to_s3() {
    echo "######################################################"
    echo " Done building, copying to s3://${BUILD_ARTIFACT_BUCKET}/${OSID}/${VERSION}"
    echo "######################################################"

    rm -rf "${S3_SOURCE}build"
    rm -rf "${S3_SOURCE}deps"
    rm -rf "${S3_SOURCE}examples"
    rm -rf "${S3_SOURCE}incremental"
    rm -rf "${S3_SOURCE}.cargo-lock"
    rm -rf "${S3_SOURCE}*.dSYM"
    rm -rf "${S3_SOURCE}*.rlib"
    rm -rf "${S3_SOURCE}.fingerprint"
    # remove *.d
    find "${S3_SOURCE}" -maxdepth 1 -name '*.d' -exec rm "{}" \;

    echo "Listing files in release dir:" | tee -a "${BUILD_LOG}"

    find "${S3_SOURCE}" -maxdepth 1 | tee -a "${BUILD_LOG}"

    echo "Copying build artifacts to s3 (source=${S3_SOURCE} destination=${S3_DESTINATION})" | tee -a "${BUILD_LOG}"
    aws --endpoint-url "${S3_HOSTNAME}"  s3 sync "${S3_SOURCE}" "${S3_DESTINATION}" | tee -a "${BUILD_LOG}"

    echo "Copying build logs to s3"
    aws --endpoint-url "${S3_HOSTNAME}" \
        s3 sync \
        "/buildlogs/" \
        "s3://${BUILD_ARTIFACT_BUCKET}/logs/" 2>&1 | grep -v InsecureRequestWarning

}

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
BUILD_LOG="/buildlogs/$(date "+%Y-%m-%d-%H-%M")-${OSID}-${VERSION}.log"
mkdir -p "/buildlogs/"
touch "${BUILD_LOG}"
echo "Dumping environment:" | tee -a "${BUILD_LOG}"

export BUILD_LOG

if [ "${OSID}" == "Unknown" ]; then
    echo "Sorry, unsupported OS, quitting" | tee -a "${BUILD_LOG}"
    exit 1
fi

if [ -z "${SOURCE_REPO}" ]; then
    SOURCE_REPO="https://github.com/kanidm/kanidm.git"
fi
BUILD_DIR="/source/${OSID}/${VERSION}"

echo "Building os=${OSID} os_version=${VERSION}" | tee -a "${BUILD_LOG}"

echo "######################################################"
echo " Setting up AWS Config" | tee -a "${BUILD_LOG}"
echo "######################################################"
    mkdir -p "$HOME/.aws/"
    cat > "$HOME/.aws/config" <<-EOF
[default]
region=us-east-1
output=json
EOF


echo "Setting default signature to v4" | tee -a "${BUILD_LOG}"
aws configure set s3.signature_version s3v4
echo "Setting output json" | tee -a "${BUILD_LOG}"
aws configure set output json

S3_SOURCE="${BUILD_DIR}/target/release/"
S3_DESTINATION="s3://${BUILD_ARTIFACT_BUCKET}/${OSID}/${VERSION}/$(uname -m)/"

echo "Testing if we can actually reach the S3 bucket, will bail if not" | tee -a "${BUILD_LOG}"
aws --endpoint-url "${S3_HOSTNAME}"  s3 ls "s3://${BUILD_ARTIFACT_BUCKET}" || exit 1

echo "######################################################"
echo " Trying to grab sccache" | tee -a "${BUILD_LOG}"
echo "######################################################"

if [ "$(which sccache | wc -l)" -ne 0 ]; then
    aws --endpoint-url "${S3_HOSTNAME}"  s3 cp "s3://${BUILD_ARTIFACT_BUCKET}/sccache-${OSID}-${VERSION}" /usr/local/bin/sccache
fi

if [ -f /usr/local/bin/sccache ]; then
    chmod +x /usr/local/bin/sccache
fi


if [ "$(which sccache | wc -l)" -ne 0 ]; then

    echo "######################################################"
    echo " Starting sccache" | tee -a "${BUILD_LOG}"
    echo "######################################################"
    SCCACHE="$(which sccache)"
    export RUSTC_WRAPPER="${SCCACHE}"
    # because sccache doesn't like incremental builds...
    export CARGO_INCREMENTAL=false

    $SCCACHE --start-server | tee -a "${BUILD_LOG}"
    sleep 2
    $SCCACHE -s | tee -a "${BUILD_LOG}"
else
    echo "######################################################"
    echo " Couldn't find sccache, boo." | tee -a "${BUILD_LOG}"
    echo "######################################################"
fi

OUTPUT="$(echo "${BUILD_OUTPUT_BASE}/${OSID}/${VERSION}/" | tr -d '"')"
echo "######################################################"
echo " Making output dir: ${OUTPUT}" | tee -a "${BUILD_LOG}"
echo "######################################################"
mkdir -p "${OUTPUT}"

RUST_VERSION="$(cat /etc/RUST_VERSION)"
echo "######################################################"
echo " Setting rust version to ${RUST_VERSION}" | tee -a "${BUILD_LOG}"
echo "######################################################"
rustup default "${RUST_VERSION}"


NEED_TO_REPLACE_SOURCE_REPO=1
if [ -f "${BUILD_DIR}/.git/config" ]; then
    echo "Found existing repo at ${BUILD_DIR}, checking to see if it's the same"
    # pull the repo source URL
    CHECK_SOURCE_REPO="$(grep url "${BUILD_DIR}/.git/config" | awk '{print $NF}')"
    if [ "${CHECK_SOURCE_REPO}" != "${SOURCE_REPO}" ]; then
        echo "Source repo has changed, was ${CHECK_SOURCE_REPO}, is now ${SOURCE_REPO}, removing source"
        NEED_TO_REPLACE_SOURCE_REPO=1
    else
        echo "Is the same, carrying on."
        NEED_TO_REPLACE_SOURCE_REPO=0
    fi

    if [ $NEED_TO_REPLACE_SOURCE_REPO -eq 0 ]; then
        # pull the current branch
        CHECK_REPO_BRANCH=$(git -C "${BUILD_DIR}" branch | grep -E '^\*' | awk '{print $NF}')
        if [ "${CHECK_REPO_BRANCH}" != "${SOURCE_REPO_BRANCH}" ]; then
            echo "Branch is different (${CHECK_REPO_BRANCH} != ${SOURCE_REPO_BRANCH}), removing source."
            NEED_TO_REPLACE_SOURCE_REPO=1
        fi
    fi
fi

cd /

if [ $NEED_TO_REPLACE_SOURCE_REPO -eq 1 ]; then
    echo "######################################################"
    echo " Cloning from ${SOURCE_REPO} into ${BUILD_DIR}" | tee -a "${BUILD_LOG}"
    echo "######################################################"
    rm -rf /source/*

    mkdir -p "/source/${OSID}"

    if [ ! -f "${BUILD_DIR}" ]; then
        echo "Cloning repo"
        git clone "${SOURCE_REPO}" "${BUILD_DIR}"
    else
        echo "Repo already exists at ${BUILD_DIR}, don't need to clone"
    fi
fi

echo "Changing working dir into ${BUILD_DIR}" | tee -a "${BUILD_LOG}"
cd "${BUILD_DIR}" || {
    echo "Failed to download source from ${SOURCE_REPO} bailing" | tee -a "${BUILD_LOG}"
    exit 1
}

git fetch --all
echo "making target dir ${BUILD_DIR}/target" | tee -a "${BUILD_LOG}"
mkdir -p "${BUILD_DIR}/target"

# change to the requested branch
if [ -n "${SOURCE_REPO_BRANCH}" ]; then
    echo "######################################################"
    echo " Config specifies to use ${SOURCE_REPO_BRANCH}" | tee -a "${BUILD_LOG}"
    echo "######################################################"
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
    # echo "######################################################"
    # echo "Doing default thing, running tests." | tee -a "${BUILD_LOG}"
    # echo "######################################################"
    # RUST_BACKTRACE=1 cargo test --release -- || {
    #     echo "Error: Failed to complete tests building  ${OSID}/${VERSION}, not doing build/copy stage" | tee -a "${BUILD_LOG}"
    #     exit 1
    # }
    echo "######################################################"
    echo " Doing build stage"
    echo "######################################################"
    cargo build --workspace --release || {
        echo "Error: failed to build ${OSID}/${VERSION}, bailing" | tee -a "${BUILD_LOG}"
        exit 1
    }

    if [ "$(which dpkg | wc -l)" -ne 0 ]; then
        echo "######################################################"
        echo " Building .deb packages" | tee -a "${BUILD_LOG}"
        echo "######################################################"
        /usr/local/sbin/build_debs.sh "${BUILD_LOG}"
    fi

fi


if [ "$(pgrep sccache | wc -l)" -ne 0 ]; then
    echo "######################################################"
    echo " sccache stats" | tee -a "${BUILD_LOG}"
    echo "######################################################"
    $SCCACHE -s | tee -a "${BUILD_LOG}"
fi

upload_to_s3

echo "Completed build for ${OSID}/${VERSION}"
