#!/bin/bash

# based on information from https://blog.serverdensity.com/how-to-create-a-debian-deb-package/


BUILD_DIR=$1
TEMPDIR=$(mktemp -d)

if [ ! -d "${BUILD_DIR}" ]; then
    echo "Coudn't find build dir (${BUILD_DIR}) bailing."
    exit 1
fi

echo "Building .deb package for kanidmd ${OSID} ${VERSION}"

##############################################################################
# All the directories
##############################################################################

mkdir -p "${TEMPDIR}/pkg-debian/DEBIAN"
# {conffiles,control,md5sums,postinst,prerm}
mkdir -p "${TEMPDIR}/pkg-debian/etc/kanidm/"
mkdir -p "${TEMPDIR}/pkg-debian/etc/systemd/system/"
mkdir -p "${TEMPDIR}/pkg-debian/var/lib/kanidm/"
touch "${TEMPDIR}/pkg-debian/var/lib/kanidm/kanidm.db"
mkdir -p "${TEMPDIR}/pkg-debian/usr/local/sbin/"

cp "${BUILD_DIR}/target/release/kanidmd" "${TEMPDIR}/pkg-debian/usr/local/sbin/" || {
    echo "Couldn't find kanidmd, quitting"
    exit 1
}



##############################################################################
# Default config
##############################################################################
cp "${BUILD_DIR}/examples/server.toml" "${TEMPDIR}/pkg-debian/etc/kanidm/kanidmd.toml" || {
    echo "Couldn't find server.toml examples, quitting"
    exit 1
}


##############################################################################
# Things that won't get deleted without a purge of this package
##############################################################################

cat > "${TEMPDIR}/pkg-debian/DEBIAN/conffiles" <<- 'EOM'
/etc/kanidm/kanidmd.toml
/var/lib/kanidm/kanidm.db
EOM

##############################################################################
# SYSTEMD SERVICE FILE
##############################################################################
cat > "${TEMPDIR}/pkg-debian/etc/systemd/system/kanidmd.service" <<- 'EOM'
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
cat > "${TEMPDIR}/pkg-debian/DEBIAN/prerm" <<- 'EOM'
if [ -f /bin/systemctl ]; then
    /bin/systemctl stop kanidmd
fi
EOM
chmod 0755 "${TEMPDIR}/pkg-debian/DEBIAN/prerm"

##############################################################################
# Post-install script
##############################################################################
cat > "${TEMPDIR}/pkg-debian/DEBIAN/postinst" <<- 'EOM'
chmod +x /usr/local/sbin/kanidmd

if [ "$(grep -c kanidm /etc/passwd)" -eq 0 ]; then
    echo "Creating user kanidm..."
    useradd --home-dir /var/lib/kanidm/ --user-group --system --shell /sbin/nologin kanidm
else
    echo "User kanidm already exists"
fi

if [ -f /bin/systemctl ]; then
    echo "Loading systemd service configuration..."
    /bin/systemctl daemon-reload
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
}  >> "${TEMPDIR}/pkg-debian/DEBIAN/control"


##############################################################################
# Generate the .deb
##############################################################################
echo "Creating the package"
dpkg -b "${TEMPDIR}/pkg-debian/" "${BUILD_DIR}/target/release/kanidmd-${KANIDM_VERSION}-${ARCH}.deb"
cp "${BUILD_DIR}/target/release/kanidmd-${KANIDM_VERSION}-${ARCH}.deb" "${BUILD_DIR}/target/release/kanidmd-latest-${ARCH}.deb"
