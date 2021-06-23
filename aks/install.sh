#!/bin/bash

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Color codes for bash output
BLUE='\e[36m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CLEAR='\e[39m'
if [[ "$COLOR" == "False" || "$COLOR" == "false" ]]; then
    BLUE='\e[39m'
    GREEN='\e[39m'
    RED='\e[39m'
    YELLOW='\e[39m'
fi

if [[ "$OS" == "darwin" ]]; then
    printf "${BLUE}Detected MacOS - attempting install with homebrew.${CLEAR}\n"
    which brew &> /dev/null
    if [ "$?" -ne 0 ]; then
        printf "${RED}Brew not installed, please install homebrew from brew.sh and re-run. Exiting.${CLEAR}\n"
        exit 1
    fi
    printf "${YELLOW}"
    brew update && brew install azure-cli
    if [ -z "$(which jq)" ]; then
        brew install jq
    fi
    printf "${CLEAR}"
elif [[ "$OS" == "linux" ]]; then
    printf "${YELLOW}"
    if [[ "$(which yum)" ]]; then
        # RHEL Linux
        printf "${BLUE}Detected Fedora-based Distro - attempting install with yum.${CLEAR}\n"
        if [ -z "$(which jq)" ]; then
            sudo yum install -y jq
        fi
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
        sudo yum install azure-cli -y
    elif [[ "$(which apt)" ]]; then
        # Debian Linux (we're guessing Ubuntu)
        printf "${BLUE}Detected Debian-based Distro - attempting install with apt.${CLEAR}\n"
        if [ -z "$(which jq)" ]; then
            sudo apt install jq
        fi
        sudo apt-get update
        sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg
        curl -sL https://packages.microsoft.com/keys/microsoft.asc |
        gpg --dearmor |
        sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
        AZ_REPO=$(lsb_release -cs)
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
        sudo tee /etc/apt/sources.list.d/azure-cli.list
        sudo apt-get update
        sudo apt-get install azure-cli
    elif [[ "$(which apk)" ]]; then
        # Alpine
        printf "${BLUE}Detected Alpine-based Distro - attempting install with apk.${CLEAR}\n"
        apk add jq
        apk del python2
        apk update
        apk add bash py-pip make gcc
        apk add --virtual=build libffi-dev musl-dev openssl-dev python3-dev
        apk add linux-headers musl-dev musl libc-dev libffi-dev
        apk add openssl-dev openssl
        apk add --no-cache ca-certificates
        apk add --no-cache --virtual .build-deps curl
        apk del .build-deps
        apk add --no-cache python3
        python3 -m ensurepip
        rm -r /usr/lib/python*/ensurepip
        python3 -m pip install --upgrade pip==21.1.1
        python3 --version && pip3 --version
        pip3 install --upgrade setuptools
        rm -r /root/.cache
        pip3 install wheel
        pip3 install --upgrade  azure-cli --no-cache-dir
    else
        # Unknown distro
        printf "${RED}Unsupported Distro. Exiting.${CLEAR}\n"
        exit 1
    fi
    printf "${CLEAR}"
else
    # Not MacOS or Linux
    printf "${RED}Unsupported OS. Exiting.${CLEAR}\n"
    exit 1
fi
