#!/bin/bash

# This pulls the kanidm version
#
# pass the build dir, or not, whatever

if [ -z "${1}" ]; then
    BUILD_DIR="."
else
    BUILD_DIR="${1}"
fi

if [ -f "${BUILD_DIR}/kanidm_tools/Cargo.toml" ]; then
    KANIDM_CARGO="${BUILD_DIR}/kanidm_tools/Cargo.toml"
else
    KANIDM_CARGO="$(find "${BUILD_DIR}" -type f -path '*kanidm*' -name Cargo.toml | head -n1)"
fi

head -n10 "${KANIDM_CARGO}" \
    | grep -Eo '^version[[:space:]].*' \
    | awk '{print $NF}' \
    | tr -d '"'
