#!/bin/bash

# based on information from https://blog.serverdensity.com/how-to-create-a-debian-deb-package/


BUILD_DIR=$1
OSID=$2
VERSION=$3
TEMPDIR=$(mktemp -d)
if [ ! -d "${BUILD_DIR}" ]; then
    echo "Coudn't find build dir (${BUILD_DIR}) bailing."
    exit 1
fi

echo "Building .deb package for kanidm ${OSID} ${VERSION}"

##############################################################################
# All the directories
##############################################################################

mkdir -p "${TEMPDIR}/pkg-debian/DEBIAN"
# {conffiles,control,md5sums,postinst,prerm}
mkdir -p "${TEMPDIR}/pkg-debian/etc/kanidm/"
mkdir -p "${TEMPDIR}/pkg-debian/usr/local/bin/"
mkdir -p "${TEMPDIR}/pkg-debian/usr/local/share/kanidm/client/"

cp "${BUILD_DIR}/target/release/kanidm" "${TEMPDIR}/pkg-debian/usr/local/bin/"

##############################################################################
# Default config
##############################################################################
cp "${BUILD_DIR}/examples/config" "${TEMPDIR}/pkg-debian/usr/local/share/kanidm/client/"

##############################################################################
# Things that won't get deleted without a purge of this package
##############################################################################

# /etc/kanidm/config
cat > "${TEMPDIR}/pkg-debian/DEBIAN/conffiles <<- 'EOM'"
EOM

# ##############################################################################
# # SYSTEMD SERVICE FILE
# ##############################################################################
# cat > "${TEMPDIR}/pkg-debian/etc/systemd/system/kanidmd.service <<- 'EOM'"
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
# cat > "${TEMPDIR}/pkg-debian/DEBIAN/prerm <<- 'EOM'"
# if [ -f /bin/systemctl ]; then
#     /bin/systemctl stop kanidmd
# fi
# EOM
# chmod 0755 "${TEMPDIR}/pkg-debian/DEBIAN/prerm"

##############################################################################
# Post-install script
##############################################################################
cat > "${TEMPDIR}/pkg-debian/DEBIAN/postinst" <<- 'EOM'
#!/bin/bash
chmod +x /usr/local/bin/kanidm
if [ ! -f /etc/kanidm/config ]; then
    echo "No config file found, copying default..."
    mkdir -p /etc/kanidm/
    cp "/usr/local/share/kanidm/client/config" "/etc/kanidm/" || exit 1
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
cat > "${TEMPDIR}/pkg-debian/DEBIAN/control <<- 'EOM'"
Package: kanidm
Essential: no
Section: web
Priority: optional
Maintainer: James Hodgkinson
Description: Kanidm CLI Client
EOM
{
    echo "Version: ${KANIDM_VERSION}"
    echo "Installed-Size: $KANIDMD_SIZE"
    echo "Architecture: ${ARCH}"
}  >> "${TEMPDIR}/pkg-debian/DEBIAN/control"


##############################################################################
# Generate the .deb
##############################################################################
echo "Creating the package"
dpkg -b "${TEMPDIR}/pkg-debian/" "${BUILD_DIR}/target/release/kanidm-${KANIDM_VERSION}-${ARCH}.deb"
