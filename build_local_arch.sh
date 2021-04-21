#!/bin/bash

# builds kanidm on the local architecture
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
    echo "Couldn't find sccache, output from 'which sccache' was:"
    which -a sccache
fi

# let's see if we're on suse
if [ -f /etc/os-release ]; then
    # SUSE-based
    if [ "$(grep -ci suse /etc/os-release)" -gt 0 ]; then
        OSID="$(grep -E '^ID=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"' )"
        if [ "$(grep -ciE '^VERSION=' /etc/os-release)" -ne 0 ]; then
            VERSION="$(grep -E '^VERSION=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"' )"
        fi
    # Debian
    elif [ "$(grep -ciE '^ID=debian' /etc/os-release)" -gt 0 ]; then
        OSID="$(grep -E '^ID=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"'  )"
        VERSION="$(grep -E '^VERSION_CODENAME=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"' )"
    # Ubuntu
    elif [ "$(grep -ciE '^ID=ubuntu' /etc/os-release)" -gt 0 ]; then
        OSID="$(grep -E '^ID=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"'  )"
        VERSION="$(grep -E '^VERSION_CODENAME=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"' )"
    fi
fi
export OSID
export VERSION

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

cd /
BUILD_DIR="/source/${OSID}/${VERSION}"
echo "######################################################"
echo " Cloning from ${SOURCE_REPO} into ${BUILD_DIR}"
echo "######################################################"

rm -rf /source/*

mkdir -p "/source/${OSID}"

git clone "${SOURCE_REPO}" "${BUILD_DIR}"

echo "Changing working dir into ${BUILD_DIR}"
cd "${BUILD_DIR}" || {
    echo "Failed to download source from ${SOURCE_REPO} bailing"
    exit 1
}
git fetch --all

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
    RUST_BACKTRACE=1 cargo test --release || {
        echo "Failed to pass tests, not doing build/copy stage"
        exit 1
    }
    cargo build --release || exit 1

    # rsync --delete -av "${BUILD_DIR}/target/release/kani*" "${OUTPUT}"
fi

echo "######################################################"
echo " Done building, copying to s3://kanidm-builds/${OSID}/${VERSION}"
echo "######################################################"


mkdir -p "$HOME/.aws/"
cat > "$HOME/.aws/config" <<-EOF
[default]

region = us-east-1
output = json
EOF

cat > "$HOME/.aws/config" <<-EOF
[default]
cli_pager=
output = json
s3 =
    signature_version = s3v4
EOF

aws --endpoint-url "${S3_HOSTNAME}" \
    s3 sync \
    "${BUILD_DIR}/target/" \
    "s3://kanidm-builds/${OSID}/${VERSION}"
