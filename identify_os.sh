#!/bin/bash


if [ -f /etc/os-release ]; then
    # SUSE-based
    if [ "$(grep -ci suse /etc/os-release)" -gt 0 ]; then
        OSID="$(grep -E '^ID=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"' )"
        if [ "$(grep -ciE '^VERSION=' /etc/os-release)" -ne 0 ]; then
            VERSION="$(grep -E '^VERSION=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"' )"
        fi
    # Debian
    elif [ "$(grep -ciE '^ID=debian' /etc/os-release)" -gt 0 ]; then
        OSID="$(grep -E '^ID=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"'  )"
        VERSION="$(grep -E '^VERSION_CODENAME=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"' )"
    # Ubuntu
    elif [ "$(grep -ciE '^ID=ubuntu' /etc/os-release)" -gt 0 ]; then
        OSID="$(grep -E '^ID=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"'  )"
        VERSION="$(grep -E '^VERSION_CODENAME=' /etc/os-release | awk -F'=' '{print $2}' | tr -d '"' )"
    fi
fi
export OSID
export VERSION