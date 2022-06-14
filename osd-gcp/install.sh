#!/bin/bash

# Color codes for bash output
BLUE='\e[36m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CLEAR='\e[39m'

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ "$OS" == "darwin" ]]; then
    if [ -z "$(which jq)" ]; then
        brew install jq
    else
        printf "${GREEN}jq version `jq --version` already installed${CLEAR}\n"
    fi

    if [ -z "$(which kubectl)" ]; then
        curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.20.0/bin/darwin/amd64/kubectl
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
        echo "kubectl version: " `kubectl version --client`
    else
        printf "${GREEN}kubectl version `kubectl version --client` already installed ${CLEAR}\n"
    fi

    if [ -z "$(which ocm)" ]; then
        curl -Lo /usr/local/bin/ocm https://github.com/openshift-online/ocm-cli/releases/download/v0.1.63/ocm-$OS-amd64
        chmod +x /usr/local/bin/ocm
        printf "${GREEN}ocm version `ocm version` installed${CLEAR}\n"
    else
        printf "${GREEN}ocm version `ocm version` already installed${CLEAR}\n"
    fi
else
    if [ -z "$(which jq)" ]; then
        sudo yum install -y jq
    fi

    if [ -z "$(which kubectl)" ]; then
      curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.20.0/bin/linux/amd64/kubectl
      chmod +x ./kubectl
      sudo mv ./kubectl /usr/local/bin/kubectl
      printf "${GREEN}kubectl installed with the following version:\n$(kubectl version --client)${CLEAR}\n"
    else
      printf "${GREEN}kubectl version `kubectl version --client` already installed ${CLEAR}\n"
    fi

    if [ -z "$(which ocm)" ]; then
        curl -Lo /usr/local/bin/ocm https://github.com/openshift-online/ocm-cli/releases/download/v0.1.63/ocm-$OS-amd64
        chmod +x /usr/local/bin/ocm
        printf "${GREEN}ocm version `ocm version` installed${CLEAR}\n"
    else
        printf "${GREEN}ocm version `ocm version` already installed${CLEAR}\n"
    fi
fi
