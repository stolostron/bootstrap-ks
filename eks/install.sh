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
    fi

    if [ -z "$(which eksctl)" ]; then
        brew tap weaveworks/tap
        brew install weaveworks/tap/eksctl
        printf "${GREEN}ekscli installed with the following version:\n$(eksctl version)${CLEAR}\n"
        https://downloads-openshift-console.apps.cahl-hub2.dev02.red-chesterfield.com/amd64/mac/oc.zip
        echo "eksctl version:" `eksctl version`
     fi

     if [ -z "$(which kubectl)" ]; then
        curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.20.0/bin/darwin/amd64/kubectl
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
        echo "kubectl version: " `kubectl version --client`
     fi

    if [ -z "$(which aws-iam-authenticator)" ]; then
        brew install aws-iam-authenticator
    fi
else
    if [ -z "$(which jq)" ]; then
        sudo yum install -y jq
    fi

    if [ -z "$(which eksctl)" ]; then
      curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
      sudo mv /tmp/eksctl /usr/local/bin
      printf "${GREEN}ekscli installed with the following version:\n$(eksctl version)${CLEAR}\n"
    fi

    if [ -z "$(which kubectl)" ]; then
      curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.20.0/bin/linux/amd64/kubectl
      chmod +x ./kubectl
      sudo mv ./kubectl /usr/local/bin/kubectl
      printf "${GREEN}kubectl installed with the following version:\n$(kubectl version)${CLEAR}\n"
    fi

    if [ -z "$(which aws-iam-authenticator)" ]; then
        curl --silent -o aws-iam-authenticator https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator
        sudo chmod +x ./aws-iam-authenticator
        sudo mv ./aws-iam-authenticator /usr/local/bin/aws-iam-authenticator
    fi

fi
