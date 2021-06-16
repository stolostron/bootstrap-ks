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

printf "${BLUE}This script will install the 'rosa' binary locally in the 'vendor' directory.${CLEAR}\n"
printf "${BLUE}If you want to install it globally, simply move the 'rosa' CLI into your path.${CLEAR}\n"

#------INSTALL AWSCLI-----#
if [[ ! $(which aws) ]]; then
    printf "${BLUE}Installing the 'aws' CLI.${CLEAR}\n"
    if [[ "$OS" == "darwin" ]]; then
        # Mac
        curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg";
        sudo installer -pkg AWSCLIV2.pkg -target /;
        printf "${GREEN}Installed the aws CLI at $(which aws) with version:${CLEAR}\n";
        printf "${YELLOW}";
        aws --version;
        printf "${CLEAR}";
    elif [[ "$OS" == "linux" ]]; then
        # Linux
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip";
        unzip awscliv2.zip;
        ./aws/install;
        printf "${GREEN}Installed the aws CLI at $(which aws) with version:${CLEAR}\n";
        printf "${YELLOW}";
        aws --version;
        printf "${CLEAR}";
    else
        echo "Unsupported OS"
        exit 1
    fi
else
    printf "${GREEN}Using the 'aws' CLI installed at $(which aws) with version:${CLEAR}\n";
    printf "${YELLOW}";
    aws --version;
    printf "${CLEAR}";
fi

#------INSTALL ROSA CLI-----#
if [[ ! $(which rosa) ]]; then
    # Make a vendor directory if it doesn't exist already.
    if [[ ! -d "./vendor" ]]; then
        mkdir vendor;
    fi;

    # Check if the rosa cli is vendorized 
    if [[ ! -x "$PWD/vendor/rosa" ]]; then
        printf "${BLUE}Installing the 'rosa' CLI.${CLEAR}\n"
        if [[ "$OS" == "darwin" ]]; then
            # Mac
            curl "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/rosa/latest/rosa-macosx.tar.gz" -o "$PWD/vendor/rosa.tar.gz" -s;
        elif [[ "$OS" == "linux" ]]; then
            # Linux
            curl "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/rosa/latest/rosa-linux.tar.gz" -o "$PWD/vendor/rosa.tar.gz" -s;
        else
            printf "${RED}Unsupported OS. Exiting${CLEAR}\n"
            exit 1
        fi
        tar -xf "$PWD/vendor/rosa.tar.gz" && mv "$PWD/rosa" "$PWD/vendor/rosa";
        printf "${GREEN}Installed the 'rosa' CLI at $PWD/vendor/rosa with version:${CLEAR}\n";
    else
        printf "${GREEN}Using vendorized 'rosa' cli at $PWD/vendor/rosa with version:${CLEAR}\n";
    fi;
    printf "${YELLOW}";
    $PWD/vendor/rosa version;
    ROSA=$PWD/vendor/rosa
    printf "${CLEAR}";
else
    printf "${GREEN}Using the 'rosa' CLI installed at $(which rosa) with version:${CLEAR}\n";
    printf "${YELLOW}";
    ROSA=$(which rosa)
    rosa version;
    printf "${CLEAR}";
fi
