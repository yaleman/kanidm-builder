#!/bin/bash

# does the post-installation thing

# shellcheck disable=SC1091
source /usr/local/lib/kanidm/build_find_pamdir.sh


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

echo "Reloading systemd service config and starting kanidm-unixd services..."
systemctl daemon-reload
systemctl --enable --now kanidm-unixd.service
systemctl --enable --now kanidm-unixd-tasks.service

echo "Finished installing kanidm-pamnss!"
