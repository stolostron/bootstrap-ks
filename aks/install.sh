#!/bin/bash

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ "$OS" == "darwin" ]]; then
    which brew &> /dev/null
    if [ "$?" -ne 0 ]; then
        echo "Brew not installed, please install homebrew from brew.sh and re-run. aborting"
        exit 1
    fi
    brew update && brew install azure-cli
else
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
    sudo yum install azure-cli -y
fi