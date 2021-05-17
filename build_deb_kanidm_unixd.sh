#!/bin/bash

# based on information from https://blog.serverdensity.com/how-to-create-a-debian-deb-package/


BUILD_DIR=$1
OSID=$2
VERSION=$3

if [ ! -d "${BUILD_DIR}" ]; then
    echo "Coudn't find build dir (${BUILD_DIR}) bailing."
    exit 1
fi

echo "Building .deb package for kanidm-unixd ${OSID} ${VERSION}"

DEB_DIR=$(mktemp -d)

##############################################################################
# All the directories
##############################################################################

mkdir -p "${DEB_DIR}/pkg-debian/DEBIAN"
# {conffiles,control,md5sums,postinst,prerm}
mkdir -p "${DEB_DIR}/pkg-debian/etc/kanidm/"
mkdir -p "${DEB_DIR}/pkg-debian/etc/systemd/system/"
# mkdir -p "${DEB_DIR}/pkg-debian/var/lib/kanidm/"
mkdir -p "${DEB_DIR}/pkg-debian/usr/local/sbin/"

find "${BUILD_DIR}/target/release/" -name 'kanidm_unixd*' -exec cp "{}" "${DEB_DIR}/pkg-debian/usr/local/sbin/" \;


##############################################################################
# Default config
##############################################################################
cp "${BUILD_DIR}/examples/unixd" "${DEB_DIR}/pkg-debian/etc/kanidm/unixd"

##############################################################################
# Things that won't get deleted without a purge of this package
##############################################################################

cat > "${DEB_DIR}/pkg-debian/DEBIAN/conffiles" <<- 'EOM'
/etc/kanidm/unixd
EOM

# ##############################################################################
# # SYSTEMD SERVICE FILE
# ##############################################################################
cat > "${DEB_DIR}/pkg-debian/etc/systemd/system/kanidm-unixd.service" <<- 'EOM'
# You should not need to edit this file. Instead, use a drop-in file as described in:
#   /usr/lib/systemd/system/kanidm_unixd.service.d/custom.conf

[Unit]
Description=Kanidm Local Client Resolver
After=network-online.target

[Service]
DynamicUser=yes
UMask=0027
CacheDirectory=kanidm-unixd
RuntimeDirectory=kanidm-unixd
Type=simple
ExecStart=/usr/local/sbin/kanidm_unixd

[Install]
WantedBy=multi-user.target

EOM

##############################################################################
# Pre-rm script
##############################################################################
cat > "${DEB_DIR}/pkg-debian/DEBIAN/prerm" <<- 'EOM'
EOM
chmod 0755 "${DEB_DIR}/pkg-debian/DEBIAN/prerm"

##############################################################################
# Post-install script
##############################################################################
cat > "${DEB_DIR}/pkg-debian/DEBIAN/postinst" <<- 'EOM'
chmod +x /usr/local/sbin/kanidm*

EOM
chmod +x "${DEB_DIR}/pkg-debian/DEBIAN/postinst"

##############################################################################
# Generate MD5SUMS
##############################################################################
find . -type f ! -regex '.*?debian-binary.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -printf '%P ' | xargs md5sum > "${DEB_DIR}/pkg-debian/DEBIAN/md5sums"

KANIDM_VERSION="$(head -n10 "${BUILD_DIR}/kanidmd/Cargo.toml" | grep -Eo '^version[[:space:]].*' | awk '{print $NF}' | tr -d '"')"

KANIDMD_SIZE="$(du -s --block-size=K "${DEB_DIR}/" | awk '{print $1}' | tr -d 'K')"
ARCH="$(dpkg --print-architecture)"
##############################################################################
# Package metadata
##############################################################################
cat > "${DEB_DIR}/pkg-debian/DEBIAN/control" <<- 'EOM'
Package: kanidm-unixd
Essential: no
Section: web
Priority: optional
Maintainer: James Hodgkinson
Description: Kanidm-unix daemon
EOM
{
    echo "Version: ${KANIDM_VERSION}"
    echo "Installed-Size: $KANIDMD_SIZE"
    echo "Architecture: ${ARCH}"
}  >> "${DEB_DIR}/pkg-debian/DEBIAN/control"


##############################################################################
# Generate the .deb
##############################################################################
echo "Creating the package"
dpkg -b "${DEB_DIR}/pkg-debian/"  "${BUILD_DIR}/target/release/kanidm-unixd-${KANIDM_VERSION}-${ARCH}.deb"
