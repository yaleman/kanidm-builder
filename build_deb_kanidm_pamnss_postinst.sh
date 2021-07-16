#!/bin/bash
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
else
    echo "Couldn't find /etc/os-release, bailing"
    exit 1
fi

if [ "${VERSION_CODENAME}" == "buster" ]; then # debian buster
    echo "Debian buster"
    NSSDIR="/usr/lib/$(uname -p)-linux-gnu"
elif [ "${VERSION_CODENAME}" == "bionic" ]; then # ubuntu bionic
    echo "Ubuntu bionic"
    NSSDIR="/lib/$(uname -p)-linux-gnu"
elif [ "${VERSION_CODENAME}" == "focal" ]; then # ubuntu focal
    echo "Ubuntu focal"
    NSSDIR="/usr/lib/$(uname -p)-linux-gnu"
elif [ "${VERSION_CODENAME}" == "groovy" ]; then # ubuntu groovy
    echo "Ubuntu groovy"
    NSSDIR="/usr/lib/$(uname -p)-linux-gnu"
fi
PAMDIR="${NSSDIR}/security"

if [ -d "${NSSDIR}" ]; then
    echo "Linking NSS lib: /usr/local/lib/kanidm/libnss_kanidm.so.2 => ${NSSDIR}/libnss_kanidm.so.2"
    ln -sf /usr/local/lib/kanidm/libnss_kanidm.so.2 "${NSSDIR}/libnss_kanidm.so.2"
    if [ -d "${PAMDIR}" ]; then
      echo "Linking PAM Module: /usr/local/lib/kanidm/pam_kanidm.so => ${PAMDIR}/pam_kanidm.so"
        ln -sf /usr/local/lib/kanidm/pam_kanidm.so "${PAMDIR}/pam_kanidm.so"
    fi
else
    echo "Couldn't find NSS dir: ${NSSDIR}, bailing"
    exit 1
fi

echo "Done!"