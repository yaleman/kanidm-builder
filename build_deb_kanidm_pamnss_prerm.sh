#!/bin/bash

""" does the cleanup-before-removal-installation thing """

if [ -d "/usr/lib/$(uname -m)-linux-gnu" ]; then
    NSSDIR="/usr/lib/$(uname -m)-linux-gnu"
elif [ -d "/lib/$(uname -m)-linux-gnu" ]; then
    NSSDIR="/lib/$(uname -m)-linux-gnu"
elif [ -d "/usr/lib/$(uname -p)-linux-gnu" ]; then
    NSSDIR="/usr/lib/$(uname -p)-linux-gnu"
elif [ -d "/lib/$(uname -p)-linux-gnu" ]; then
    NSSDIR="/lib/$(uname -p)-linux-gnu"
else
    echo "Couldn't figure out where the NSS dir is? uname -p = $(uname -p) uname -m = $(uname -m)"
fi

PAMDIR="${NSSDIR}/security"



############ PRE-REMOVAL STUFF


if [ -d "${NSSDIR}" ]; then
    echo "Removing symlinks..."
    rm "${NSSDIR}/libnss_kanidm.so.2"
    if [ -d "${PAMDIR}" ]; then
        rm "${PAMDIR}/pam_kanidm.so"
    else
        echo "Couldn't find PAM dir, probably need to clean that up manually. Looked in: ${PAMDIR}"
    fi
else
    echo "Couldn't find NSS dir: ${NSSDIR}, bailing"
    exit 1
fi

echo "Done!"