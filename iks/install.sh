#!/bin/bash

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
      apk add jq
    fi
else
    echo "Unsupported OS"
    exit 1

fi

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
ibmcloud plugin install container-service
if [ $? -ne 0 ]; then
    echo "IBM Cloud CLI kubernetes plugin installation failed, exiting with a failure"
    exit 1;
else
    echo "IBM Cloud CLI kubernetes pluing version installed successfullly."
fi
