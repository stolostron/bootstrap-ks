#!/bin/bash

# Color codes for bash output
BLUE='\e[36m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CLEAR='\e[39m'

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Mac
if [[ "$OS" == "darwin" ]]; then
    if [ -z "$(which jq)" ]; then
        brew install jq
    fi

    if [ -z "$(which python3)" ]; then
        brew install python3
    fi
    if [[ ! ("$(python3 --version)" =~ Python\ 3\.[5,6,7,8,9][0-9]*\.[0-9]+ ) ]]; then
        printf "${RED}Python version '$(python3 --version)' does not match required version for gcloud cli installation (requires python 3.5 or above).\n"
        printf "Please update python on your system. exiting.\n${CLEAR}"
        exit 1
    fi
    curl -X GET --output google-cloud-sdk-301.0.0-darwin-x86_64.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-301.0.0-darwin-x86_64.tar.gz
    tar -xf google-cloud-sdk-301.0.0-darwin-x86_64.tar.gz
    ./google-cloud-sdk/install.sh -q --rc-path=~/.bash_profile --path-update=true --usage-reporting=false
    source ~/.bash_profile
    printf "${GREEN}gcloud cli installed with the following versions:\n$(gcloud --version)${CLEAR}\n"
elif [[ "$OS" == "linux" ]]; then
  if [ -z "$JENKINS_HOME" ]; then
    # RHEL Linux
    if [ -z "$(which jq)" ]; then
        sudo yum install -y jq
    fi
    if [ -z "$(which python)" ]; then
        sudo yum install -y python2
    fi

    # Update YUM with Cloud SDK repo information:
    sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM

    # Install the Cloud SDK
    sudo yum install -y google-cloud-sdk

    gcloud version

  else
    # Install for Jenkins alpine
    apk add python

    export GKE_DIRECTORY="$PWD/GoogleCloudSDK/google-cloud-sdk/bin"
    if [ ! -d "$GKE_DIRECTORY" ]; then
      mkdir GoogleCloudSDK
    	wget https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.zip -O google-cloud-sdk.zip
    	unzip -o google-cloud-sdk.zip -d ./GoogleCloudSDK/
    	./GoogleCloudSDK/google-cloud-sdk/install.sh
    fi
    export PATH=${GKE_DIRECTORY}:$PATH

    gcloud version
  fi
else
  echo "Unsupported OS"
  exit 1
fi
