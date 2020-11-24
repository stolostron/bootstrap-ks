#!/bin/bash

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ "$OS" == "darwin" ]]; then
    which brew &> /dev/null
    if [ "$?" -ne 0 ]; then
        echo "Brew not installed, please install homebrew from brew.sh and re-run. aborting"
        exit 1
    fi
    brew update && brew install azure-cli

    if [ -z "$(which jq)" ]; then
        brew install jq
    fi
elif [[ "$OS" == "linux" ]]; then
    if [ -z "$JENKINS_HOME" ]; then
      # RHEL Linux
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

    else
      # Jenkins alpine
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

      #apk add --no-cache curl tar openssl sudo bash jq

      apk add --no-cache python3
      python3 -m ensurepip
      rm -r /usr/lib/python*/ensurepip
      pip3 install --upgrade pip setuptools
#      if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip ; fi
#      if [[ ! -e /usr/bin/python ]]; then ln -sf /usr/bin/python3 /usr/bin/python; fi
      rm -r /root/.cache

      pip3 install wheel
      pip3 install --upgrade  azure-cli --no-cache-dir
    fi
else
fi
