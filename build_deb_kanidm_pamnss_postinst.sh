#!/bin/bash

""" does the post-installation thing """

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



############ POST INSTALLATION STUFF


if [ -d "${NSSDIR}" ]; then
    echo "Linking NSS lib: /usr/local/lib/kanidm/libnss_kanidm.so.2 => ${NSSDIR}/libnss_kanidm.so.2"
    ln -sf /usr/local/lib/kanidm/libnss_kanidm.so.2 "${NSSDIR}/libnss_kanidm.so.2"
    if [ -d "${PAMDIR}" ]; then
      echo "Linking PAM Module: /usr/local/lib/kanidm/pam_kanidm.so => ${PAMDIR}/pam_kanidm.so"
        ln -sf /usr/local/lib/kanidm/pam_kanidm.so "${PAMDIR}/pam_kanidm.so"
    else
        echo "Couldn't find PAM module dir: ${PAMDIR}, bailing."
        exit 1
    fi
else
    echo "Couldn't find NSS dir: ${NSSDIR}, bailing"
    exit 1
fi

echo "Done!"
