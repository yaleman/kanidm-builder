#!/bin/bash

# based on information from https://blog.serverdensity.com/how-to-create-a-debian-deb-package/


BUILD_DIR=$1
TEMPDIR=$(mktemp -d)

if [ ! -d "${BUILD_DIR}" ]; then
    echo "Coudn't find build dir (${BUILD_DIR}) bailing."
    exit 1
fi

echo "Building .deb package for kanidm-pamnss ${OSID} ${VERSION}"

##############################################################################
# All the directories
##############################################################################

mkdir -p "${TEMPDIR}/pkg-debian/DEBIAN"
# {conffiles,control,md5sums,postinst,prerm}
mkdir -p "${TEMPDIR}/pkg-debian/usr/local/lib/kanidm/"

chmod +x "$/usr/local/sbin/build_find_pamdir.sh"
cp "/usr/local/sbin/build_find_pamdir.sh" "${TEMPDIR}/pkg-debian/usr/local/lib/kanidm/"

cp "${BUILD_DIR}/target/release/libpam_kanidm.so" "${TEMPDIR}/pkg-debian/usr/local/lib/kanidm/pam_kanidm.so"  || {
    echo "Couldn't find libpam_kanidm.so, quitting"
    exit 1
}
cp "${BUILD_DIR}/target/release/libnss_kanidm.so" "${TEMPDIR}/pkg-debian/usr/local/lib/kanidm/libnss_kanidm.so.2"  || {
    echo "Couldn't find libpam_libnss_kanidm.so.2, quitting"
    exit 1
}


##############################################################################
# Default config
##############################################################################
# cp "${BUILD_DIR}/examples/server.toml" "${TEMPDIR}/pkg-debian/etc/kanidm/kanidmd.toml"

##############################################################################
# Things that won't get deleted without a purge of this package
##############################################################################

cat > "${TEMPDIR}/pkg-debian/DEBIAN/conffiles" <<- 'EOM'
/usr/local/lib/kanidm/
EOM



##############################################################################
# Post-install script
##############################################################################
cp /usr/local/sbin/build_deb_kanidm_pamnss_postinst.sh "${TEMPDIR}/pkg-debian/DEBIAN/postinst"
chmod +x "${TEMPDIR}/pkg-debian/DEBIAN/postinst"
##############################################################################
# Pre-removal script
##############################################################################
cp /usr/local/sbin/build_deb_kanidm_pamnss_prerm.sh "${TEMPDIR}/pkg-debian/DEBIAN/prerm"
chmod +x "${TEMPDIR}/pkg-debian/DEBIAN/prerm"

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
Package: kanidm-pamnss
Essential: no
Section: web
Priority: optional
Maintainer: James Hodgkinson
Description: PAM and NSS Kanidm Modules
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
dpkg -b "${TEMPDIR}/pkg-debian/" "${BUILD_DIR}/target/release/kanidm-pamnss-${KANIDM_VERSION}-${ARCH}.deb"

echo "Fixing the weird packaging issue"
ar x "${BUILD_DIR}/target/release/kanidm-pamnss-${KANIDM_VERSION}-${ARCH}.deb" data.tar.xz
unxz data.tar.xz
tar --delete --occurrence -f data.tar ./usr/local/lib
tar --delete --occurrence -f data.tar ./usr/local/
tar --delete --occurrence -f data.tar ./usr/
xz data.tar
ar r "${BUILD_DIR}/target/release/kanidm-pamnss-${KANIDM_VERSION}-${ARCH}.deb" data.tar.xz
rm data.tar.xz



cp "${BUILD_DIR}/target/release/kanidm-pamnss-${KANIDM_VERSION}-${ARCH}.deb" "${BUILD_DIR}/target/release/kanidm-pamnss-latest-${ARCH}.deb"
