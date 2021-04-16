#!/bin/bash

curl --proto '=https' --tlsv1.2 --output /tmp/rustup.sh -sSf https://sh.rustup.rs
chmod +x /tmp/rustup.sh
/tmp/rustup.sh -y
rm /tmp/rustup.sh


PATH=/root/.cargo/bin:$PATH
export PATH


rustup update
rustup default 1.49.0