#!/bin/bash

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ "$OS" == "darwin" ]]; then
    if [ -z "$(which jq)" ]; then
        brew install jq
    fi
else
    if [ -z "$(which jq)" ]; then
        sudo yum install -y jq
    fi
fi


curl -sL https://ibm.biz/idt-installer | bash

if [ $? -ne 0 ]; then
    echo "IBM Cloud CLI installation failed, exiting with a failure"
    exit 1;
else
    echo "IBM Cloud CLI version $(ibmcloud version) installed successfullly."
fi
