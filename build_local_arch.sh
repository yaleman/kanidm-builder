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
BUILD_DIR="/source/${OSID}/${VERSION}"

echo "Building os=${OSID} os_version=${VERSION}"

echo "######################################################"
echo " Setting up AWS Config"
echo "######################################################"
    mkdir -p "$HOME/.aws/"
    cat > "$HOME/.aws/config" <<-EOF
[default]
region=us-east-1
output=json
EOF


echo "Setting default signature to v4"
aws configure set s3.signature_version s3v4
echo "Setting output json"
aws configure set output json

S3_SOURCE="${BUILD_DIR}/target/release/"
S3_DESTINATION="s3://${BUILD_ARTIFACT_BUCKET}/${OSID}/${VERSION}/$(uname -m)/"


echo "######################################################"
echo " Trying to grab sccache"
echo "######################################################"

if [ "$(which sccache | wc -l)" -ne 0 ]; then
    aws --endpoint-url "${S3_HOSTNAME}"  s3 cp "s3://kanidm-builds/sccache-${OSID}-${VERSION}" /usr/local/bin/sccache
    chmod +x /usr/local/bin/sccache
fi

if [ -f /usr/local/bin/sccache ]; then
    chmod +x /usr/local/bin/sccache
fi


if [ "$(which sccache | wc -l)" -ne 0 ]; then

    echo "######################################################"
    echo " Starting sccache"
    echo "######################################################"
    SCCACHE="$(which sccache)"
    export RUSTC_WRAPPER="${SCCACHE}"
    # because sccache doesn't like incremental builds...
    export CARGO_INCREMENTAL=false

    $SCCACHE --start-server
    sleep 2
    $SCCACHE -s
else
    echo "######################################################"
    echo " Couldn't find sccache, boo."
    echo "######################################################"
fi

OUTPUT="$(echo "${BUILD_OUTPUT_BASE}/${OSID}/${VERSION}/" | tr -d '"')"
echo "######################################################"
echo " Making output dir: ${OUTPUT}"
echo "######################################################"
mkdir -p "${OUTPUT}"

RUST_VERSION="$(cat /etc/RUST_VERSION)"
echo "######################################################"
echo " Setting rust version to ${RUST_VERSION}"
echo "######################################################"
rustup default "${RUST_VERSION}"

cd /
echo "######################################################"
echo " Cloning from ${SOURCE_REPO} into ${BUILD_DIR}"
echo "######################################################"

rm -rf /source/*

mkdir -p "/source/${OSID}"
mkdir -p "/buildlogs/"
BUILD_LOG="/buildlogs/$(date "+%Y-%m-%d-%H-%M")-${OSID}-${VERSION}.log"

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
    echo " Config specifies to use ${SOURCE_REPO_BRANCH}"
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
    # echo "######################################################"
    # echo " Skipping tests due to #416."
    # echo "######################################################"
    echo "######################################################"
    echo "Doing default thing, running tests."
    echo "######################################################"
    RUST_BACKTRACE=1 cargo test --release || {
        echo "Failed to pass tests, not doing build/copy stage"
        exit 1
    }
    echo "######################################################"
    echo " Doing build stage"
    echo "######################################################"
    cargo build --workspace --bins --release || {
        echo "unable to build, bailing"
        exit 1
    }

    if [ "$(which dpkg | wc -l)" -ne 0 ]; then
        echo "######################################################"
        echo " Building .deb package"
        echo "######################################################"
        /usr/local/sbin/build_deb_kanidmd.sh "${BUILD_DIR}" "${OSID}" "${VERSION}"
        /usr/local/sbin/build_deb_kanidm.sh "${BUILD_DIR}" "${OSID}" "${VERSION}"
        /usr/local/sbin/build_deb_kanidm_ssh.sh "${BUILD_DIR}" "${OSID}" "${VERSION}"
        /usr/local/sbin/build_deb_kanidm_unixd.sh "${BUILD_DIR}" "${OSID}" "${VERSION}"
    fi

    echo "######################################################"
    echo " Done building, copying to s3://${BUILD_ARTIFACT_BUCKET}/${OSID}/${VERSION}"
    echo "######################################################"

    rm -rf "${S3_SOURCE}build"
    rm -rf "${S3_SOURCE}deps"
    rm -rf "${S3_SOURCE}examples"
    rm -rf "${S3_SOURCE}incremental"
    rm -rf "${S3_SOURCE}.cargo.lock"
    rm -rf "${S3_SOURCE}*.dSYM"
    rm -rf "${S3_SOURCE}.fingerprint"
    # remove *.d
    find "${S3_SOURCE}" -maxdepth 1 -name '*.d' -exec rm "{}" \;

    echo "Listing files in release dir:"

    find "${S3_SOURCE}" -maxdepth 1 | tee -a "${BUILD_LOG}"

    echo "Copying build artifacts to s3 (source=${S3_SOURCE} destination=${S3_DESTINATION})"
    aws --endpoint-url "${S3_HOSTNAME}"  s3 sync "${S3_SOURCE}" "${S3_DESTINATION}"

    echo "Copying build logs to s3"
    aws --endpoint-url "${S3_HOSTNAME}" \
        s3 sync \
        "/buildlogs/" \
        "s3://${BUILD_ARTIFACT_BUCKET}/logs/" 2>&1 | grep -v InsecureRequestWarning
fi

if [ "$(pgrep sccache | wc -l)" -ne 0 ]; then
    echo "######################################################"
    echo " sccache stats"
    echo "######################################################"
    $SCCACHE -s
fi
echo "######################################################"
echo " All done!"
echo "######################################################"
