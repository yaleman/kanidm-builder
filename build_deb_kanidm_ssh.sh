#!/bin/bash

# based on information from https://blog.serverdensity.com/how-to-create-a-debian-deb-package/


BUILD_DIR=$1
TEMPDIR=$(mktemp -d)
if [ ! -d "${BUILD_DIR}" ]; then
    echo "Coudn't find build dir (${BUILD_DIR}) bailing."
    exit 1
fi

echo "Building .deb package for kanidm-ssh ${OSID} ${VERSION}"

##############################################################################
# All the directories
##############################################################################

mkdir -p "${TEMPDIR}/pkg-debian/DEBIAN"
mkdir -p "${TEMPDIR}/pkg-debian/etc/kanidm/"
mkdir -p "${TEMPDIR}/pkg-debian/usr/local/sbin/"
mkdir -p "${TEMPDIR}/pkg-debian/usr/local/share/kanidm/ssh/"


cp "${BUILD_DIR}/target/release/kanidm_ssh_authorizedkeys" "${TEMPDIR}/pkg-debian/usr/local/sbin/"  || {
    echo "Couldn't find kanidm_ssh_authorizedkeys, quitting"
    exit 1
}
cp "${BUILD_DIR}/target/release/kanidm_ssh_authorizedkeys_direct" "${TEMPDIR}/pkg-debian/usr/local/sbin/"  || {
    echo "Couldn't find kanidm_ssh_authorizedkeys_direct, quitting"
    exit 1
}

##############################################################################
# Default config
##############################################################################
cp "${BUILD_DIR}/examples/config" "${TEMPDIR}/pkg-debian/usr/local/share/kanidm/ssh/"

##############################################################################
# Things that won't get deleted without a purge of this package
##############################################################################
touch "${TEMPDIR}/pkg-debian/DEBIAN/conffiles"

# cat > "${TEMPDIR}/pkg-debian/DEBIAN/conffiles" <<- 'EOM'
# EOM

# ##############################################################################
# # SYSTEMD SERVICE FILE
# ##############################################################################
# cat > "${TEMPDIR}/pkg-debian/etc/systemd/system/kanidmd.service" <<- 'EOM'
# [Unit]
# Description=kanidm, the IDM for rustaceans
# After=network-online.target
# Wants=network-online.target

# [Service]
# Type=simple
# User=kanidm
# ExecStart=/usr/local/sbin/kanidmd server --config=/etc/kandim/kanidmd.toml
# Restart=on-failure
# RestartSec=15s
# WorkingDirectory=/var/lib/kanidm

# [Install]
# WantedBy=multi-user.target

# EOM

##############################################################################
# Pre-rm script
##############################################################################
cat > "${TEMPDIR}/pkg-debian/DEBIAN/prerm" <<- 'EOM'
EOM
chmod 0755 "${TEMPDIR}/pkg-debian/DEBIAN/prerm"

##############################################################################
# Post-install script
##############################################################################
cat > "${TEMPDIR}/pkg-debian/DEBIAN/postinst" <<- 'EOM'
#!/bin/bash
find /usr/local/sbin/ -type f -name 'kanidm_ssh*' -exec chmod +x {} \;
if [ ! -f /etc/kanidm/config ]; then
    echo "No config file found, copying default..."
    mkdir -p /etc/kanidm/
    cp "/usr/local/share/kanidm/ssh/config" "/etc/kanidm/" || exit 1
fi

EOM
chmod +x "${TEMPDIR}/pkg-debian/DEBIAN/postinst"

##############################################################################
# Generate MD5SUMS
##############################################################################
find . -type f ! -regex '.*?debian-binary.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -printf '%P ' | xargs md5sum > "${TEMPDIR}/pkg-debian/DEBIAN/md5sums"

KANIDM_VERSION="$(head -n10 "${BUILD_DIR}/kanidmd/Cargo.toml" | grep -Eo '^version[[:space:]].*' | awk '{print $NF}' | tr -d '"')"

KANIDMD_SIZE="$(du -s --block-size=K "${TEMPDIR}/" | awk '{print $1}' | tr -d 'K')"
ARCH="$(dpkg --print-architecture)"
##############################################################################
# Package metadata
##############################################################################
cat > "${TEMPDIR}/pkg-debian/DEBIAN/control" <<- 'EOM'
Package: kanidm-ssh
Essential: no
Section: web
Priority: optional
Maintainer: James Hodgkinson
Description: Kanidm SSH Utils
EOM
{
    echo "Version: ${KANIDM_VERSION}-$(date +%s)"
    echo "Installed-Size: $KANIDMD_SIZE"
    echo "Architecture: ${ARCH}"
}  >> "${TEMPDIR}/pkg-debian/DEBIAN/control"

##############################################################################
# Generate the .deb
##############################################################################
echo "Creating the package"
KANIDM_PACKAGE="${BUILD_DIR}/target/release/kanidm-ssh-${KANIDM_VERSION}-${ARCH}.deb"
dpkg -b "${TEMPDIR}/pkg-debian/" "${KANIDM_PACKAGE}"

# fix from https://stackoverflow.com/questions/13021002/my-deb-file-removes-opt/58066154#58066154
echo "Fixing the weird packaging issue"
ar x "${KANIDM_PACKAGE}" data.tar.xz
unxz data.tar.xz
tar --delete --occurrence -f data.tar ./usr/local/share
tar --delete --occurrence -f data.tar ./usr/local
tar --delete --occurrence -f data.tar ./usr
xz data.tar
ar r "${KANIDM_PACKAGE}" data.tar.xz
rm data.tar.xz


cp "${KANIDM_PACKAGE}" "${BUILD_DIR}/target/release/kanidm-ssh-latest-${ARCH}.deb"

echo "Done running build_deb_kanidm_ssh.sh"
