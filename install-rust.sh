#!/bin/bash

if [ -f "/etc/RUST_VERSION" ]; then
    RUST_VERSION="$(cat /etc/RUST_VERSION)"
elif [ -f "./RUST_VERSION" ]; then
    RUST_VERSION="$(cat ./RUST_VERSION)"
else
    echo "Couldn't find RUST_VERSION in either /etc/ or ./"
    exit 1
fi


echo "Installing rust ${RUST_VERSION} with rustup"
curl --proto '=https' --tlsv1.2 --output /tmp/rustup.sh -sSf https://sh.rustup.rs
chmod +x /tmp/rustup.sh
/tmp/rustup.sh -y
rm /tmp/rustup.sh

PATH=/root/.cargo/bin:$PATH
export PATH

rustup update
rustup default "${RUST_VERSION}"
