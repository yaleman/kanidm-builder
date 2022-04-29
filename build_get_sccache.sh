#!/bin/bash

# Tries to grab a current version of sccache

SCCACHE_DOWNLOAD_URL="$(curl -s -L https://api.github.com/repos/mozilla/sccache/releases/latest     \
    | jq -r '.assets[] | .browser_download_url' \
    | grep -vE 'sha256$'     \
    | grep -v dist \
    | grep "$(uname -m | tr "[:upper:]" "[:lower:]" )" \
    | grep "$(uname -s | tr "[:upper:]" "[:lower:]" )" \
    | tr "[:upper:]" "[:lower:]")"

if [ -z "${SCCACHE_DOWNLOAD_URL}" ]; then
    echo "Couldn't find it... "
    echo "uname -m = $(uname -m | tr "[:upper:]" "[:lower:]"))"
    echo "uname -s = $(uname -s | tr "[:upper:]" "[:lower:]"))"
    exit 1
fi

curl -L -o /tmp/sccache.tar.gz "${SCCACHE_DOWNLOAD_URL}"

if [ ! -f /tmp/sccache.tar.gz ]; then
    echo "Failed to download sccache!"
    exit 1
fi

cd /tmp/ || exit 1
tar zxvf /tmp/sccache.tar.gz

find /tmp/sccache* -type f -name sccache -exec mv {} /usr/local/bin/ \;
chmod +x /usr/local/bin/sccache

if [ "$(/usr/local/bin/sccache --version | grep -c sccache)" -eq 1 ]; then
    echo "Success!"
else
    echo "Failed to run sccache? Looking in /usr/local/bin/"
    ls -la /usr/local/bin/
    exit 1
fi
