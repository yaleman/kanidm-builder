#!/bin/bash

# builds debs

if [ -z "${BUILD_LOG}" ]; then
    BUILD_LOG=$1
    if [ -z "${BUILD_LOG}" ]; then
        echo "Please set a build log destination"
        exit 1
    fi
fi

# shellcheck disable=SC1091
source /etc/profile.d/identify_os.sh

if [ -d "/data/${OSID}/${VERSION}" ]; then
    echo "Found build dir in /data"
    BUILD_DIR="/data/${OSID}/${VERSION}"
elif [ -d "/source/${OSID}/${VERSION}" ]; then
    echo "Found build dir in /source"
    BUILD_DIR="/source/${OSID}/${VERSION}"
else
    BUILD_DIR=$2
fi

echo "Build dir: ${BUILD_DIR}"
echo "Build logs: ${BUILD_LOG}"


touch "${BUILD_LOG}"
echo "Building debs" | tee -a "${BUILD_LOG}"

/usr/local/sbin/build_deb_kanidm.sh "${BUILD_DIR}" | tee -a "${BUILD_LOG}"
/usr/local/sbin/build_deb_kanidmd.sh "${BUILD_DIR}" | tee -a "${BUILD_LOG}"
/usr/local/sbin/build_deb_kanidm_ssh.sh "${BUILD_DIR}" | tee -a "${BUILD_LOG}"
/usr/local/sbin/build_deb_kanidm_unixd.sh "${BUILD_DIR}" | tee -a "${BUILD_LOG}"
/usr/local/sbin/build_deb_kanidm_pamnss.sh "${BUILD_DIR}" | tee -a "${BUILD_LOG}"