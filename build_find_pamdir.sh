#!/usr/bin/env bash

# build_find_pamdir.sh
# tries to find the directories to put the PAM and NSS modules in, if it can find a PAM dir then it's


if [ -d "/lib/$(uname -p)-linux-gnu/security" ]; then
    NSSDIR="/lib/$(uname -p)-linux-gnu"
elif [ -d "/usr/lib/$(uname -m)-linux-gnu/security" ]; then
    NSSDIR="/usr/lib/$(uname -m)-linux-gnu"
elif [ -d "/lib/$(uname -m)-linux-gnu/security" ]; then
    NSSDIR="/lib/$(uname -m)-linux-gnu/security"
elif [ -d "/usr/lib/$(uname -p)-linux-gnu/security" ]; then
    NSSDIR="/usr/lib/$(uname -p)-linux-gnu"
else
    echo "Couldn't figure out where the NSS dir is? uname -p = $(uname -p) uname -m = $(uname -m)"
fi


PAMDIR="${NSSDIR}/security"

export NSSDIR
export PAMDIR