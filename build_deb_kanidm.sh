#!/bin/bash

# based on information from https://blog.serverdensity.com/how-to-create-a-debian-deb-package/


BUILD_DIR=$1
#OSID=$2
#VERSION=$3
TEMPDIR=$(mktemp -d)
if [ ! -d "${BUILD_DIR}" ]; then
    echo "Coudn't find build dir (${BUILD_DIR}) bailing."
    exit 1
fi

echo "Building .deb package for kanidm ${OSID} ${VERSION}"

##############################################################################
# All the directories
##############################################################################

echo "Making directories"
mkdir -p "${TEMPDIR}/pkg-debian/DEBIAN"
# {conffiles,control,md5sums,postinst,prerm}
mkdir -p "${TEMPDIR}/pkg-debian/etc/kanidm/"
mkdir -p "${TEMPDIR}/pkg-debian/usr/local/bin/"
mkdir -p "${TEMPDIR}/pkg-debian/usr/local/share/kanidm/client/"

echo "Copying release file"
cp "${BUILD_DIR}/target/release/kanidm" "${TEMPDIR}/pkg-debian/usr/local/bin/"

##############################################################################
# Default config
##############################################################################
echo "Writing default config"
cp "${BUILD_DIR}/examples/config" "${TEMPDIR}/pkg-debian/usr/local/share/kanidm/client/"

##############################################################################
# Things that won't get deleted without a purge of this package
##############################################################################

# /etc/kanidm/config
touch "${TEMPDIR}/pkg-debian/DEBIAN/conffiles"
# cat > "${TEMPDIR}/pkg-debian/DEBIAN/conffiles" <<- 'EOM'
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
echo "Writing post-install script"
cat > "${TEMPDIR}/pkg-debian/DEBIAN/postinst" <<- 'EOM'
#!/bin/bash
chmod +x /usr/local/bin/kanidm
if [ ! -f /etc/kanidm/config ]; then
    echo "No config file found, copying default..."
    mkdir -p /etc/kanidm/
    cp "/usr/local/share/kanidm/client/config" "/etc/kanidm/" || exit 1
fi

EOM

echo "Chmod postinst +x"

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
echo "Writing package metadata"
cat > "${TEMPDIR}/pkg-debian/DEBIAN/control" <<- 'EOM'
Package: kanidm
Essential: no
Section: web
Priority: optional
Maintainer: James Hodgkinson
Description: Kanidm CLI Client
EOM

{
    echo "Version: ${KANIDM_VERSION}"
    echo "Installed-Size: ${KANIDMD_SIZE}"
    echo "Architecture: ${ARCH}"
}  >> "${TEMPDIR}/pkg-debian/DEBIAN/control"


##############################################################################
# Generate the .deb
##############################################################################
echo "Creating the package"
dpkg -b "${TEMPDIR}/pkg-debian/" "${BUILD_DIR}/target/release/kanidm-${KANIDM_VERSION}-${ARCH}.deb"
cp "${BUILD_DIR}/target/release/kanidm-${KANIDM_VERSION}-${ARCH}.deb" "${BUILD_DIR}/target/release/kanidm-latest-${ARCH}.deb"

echo "Listing current .debs"

ls "${BUILD_DIR}/target/release/*.deb"

echo "Done running build_deb_kanidm.sh"