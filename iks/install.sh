#!/bin/bash

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

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ "$OS" == "darwin" ]]; then
    if [ -z "$(which jq)" ]; then
        brew install jq
    fi
elif [[ "$OS" == "linux" ]]; then
    if [ -z "$JENKINS_HOME" ]; then
      # RHEL Linux
      if [ -z "$(which jq)" ]; then
          sudo yum install -y jq
      fi
    else
      # Install for Jenkins alpine
      if [ -z "$(which jq)" ]; then
          apk add jq
      fi
    fi
else
    echo "Unsupported OS"
    exit 1
fi

if [ -z "$(which ibmcloud)" ]; then
    wget https://clis.cloud.ibm.com/download/bluemix-cli/latest/linux64 -O ibmcloud-cli.tar.gz
    tar -xvzf ibmcloud-cli.tar.gz
    rm ibmcloud-cli.tar.gz
    Bluemix_CLI/install
    if [ $? -ne 0 ]; then
      echo "IBM Cloud CLI installation failed, exiting with a failure"
      exit 1;
    else
      echo "IBM Cloud CLI version $(ibmcloud version) installed successfullly."
    fi

    ibmcloud version
    curl --progress-bar -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    ibmcloud plugin install container-service -f
    if [ $? -ne 0 ]; then
      echo "IBM Cloud CLI kubernetes plugin installation failed, exiting with a failure"
      exit 1;
    else
      echo "IBM Cloud CLI kubernetes pluing version installed successfullly."
    fi
fi
