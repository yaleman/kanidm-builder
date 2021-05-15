#!/bin/bash

# make the package directories

BUILD_DIR=$1
OSID=$2
VERSION=$3

if [ ! -d "${BUILD_DIR}" ]; then
    echo "Coudn't find build dir (${BUILD_DIR}) bailing."
    exit 1
fi

echo "Building .deb package for ${OSID} ${VERSION}"

##############################################################################
# All the directories
##############################################################################

mkdir -p /tmp/kanidmd/pkg-debian/DEBIAN
# {conffiles,control,md5sums,postinst,prerm}
mkdir -p /tmp/kanidmd/pkg-debian/etc/kanidm/
mkdir -p /tmp/kanidmd/pkg-debian/etc/systemd/system/
mkdir -p /tmp/kanidmd/pkg-debian/var/lib/kanidm/
touch /tmp/kanidmd/pkg-debian/var/lib/kanidm/kanidm.db
mkdir -p /tmp/kanidmd/pkg-debian/usr/local/sbin/

cp "${BUILD_DIR}/target/release/kanidmd" /tmp/kanidmd/pkg-debian/usr/local/sbin/


##############################################################################
# Default config
##############################################################################
cp "${BUILD_DIR}/examples/server.toml" /tmp/kanidmd/pkg-debian/etc/kanidm/kanidmd.toml

##############################################################################
# Things that won't get deleted without a purge of this package
##############################################################################

cat > /tmp/kanidmd/pkg-debian/DEBIAN/conffiles <<- 'EOM'
/etc/kanidm/kanidmd.toml
/var/lib/kanidm/kanidm.db
EOM

##############################################################################
# SYSTEMD SERVICE FILE
##############################################################################
cat > /tmp/kanidmd/pkg-debian/etc/systemd/system/kanidmd.service <<- 'EOM'
[Unit]
Description=kanidm, the IDM for rustaceans
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=kanidm
ExecStart=/usr/local/sbin/kanidmd server --config=/etc/kandim/kanidmd.toml
Restart=on-failure
RestartSec=15s
WorkingDirectory=/var/lib/kanidm

[Install]
WantedBy=multi-user.target

EOM

##############################################################################
# Pre-rm script
##############################################################################
cat > /tmp/kanidmd/pkg-debian/DEBIAN/prerm <<- 'EOM'
/bin/systemctl stop kanidmd

EOM
chmod 0755 /tmp/kanidmd/pkg-debian/DEBIAN/prerm

##############################################################################
# Post-install script
##############################################################################
cat > /tmp/kanidmd/pkg-debian/DEBIAN/postinst <<- 'EOM'
useradd --defaults --home-dir /var/lib/kanidm/ --user-group --system --shell /bin/ kanidm

chmod +x /usr/local/sbin/kanidmd

/bin/systemctl daemon-reload

EOM
chmod +x /tmp/kanidmd/pkg-debian/DEBIAN/postinst

##############################################################################
# Generate MD5SUMS
##############################################################################
find . -type f ! -regex '.*?debian-binary.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -printf '%P ' | xargs md5sum > /tmp/kanidmd/pkg-debian/DEBIAN/md5sums

KANIDM_VERSION="$(head -n10 "${BUILD_DIR}/kanidmd/Cargo.toml" | grep -Eo '^version[[:space:]].*' | awk '{print $NF}' | tr -d '"')"

KANIDMD_SIZE="$(du -s --block-size=K "/tmp/kanidmd/" | awk '{print $1}' | tr -d 'K')"
ARCH="$(uname -m | tr _ -)"
##############################################################################
# Package metadata
##############################################################################
cat > /tmp/kanidmd/pkg-debian/DEBIAN/control <<- 'EOM'
Package: kanidmd
Essential: no
Section: web
Priority: optional
Maintainer: James Hodgkinson
Description: Kanidm Daemon
EOM
{
    echo "Version: ${KANIDM_VERSION}"
    echo "Installed-Size: $KANIDMD_SIZE"
    echo "Architecture: ${ARCH}"
}  >> /tmp/kanidmd/pkg-debian/DEBIAN/control


##############################################################################
# Generate the .deb
##############################################################################
echo "Creating the package"
dpkg -b /tmp/kanidmd/pkg-debian/  "${BUILD_DIR}/target/release/kanidmd-${KANIDM_VERSION}-${ARCH}.deb"
