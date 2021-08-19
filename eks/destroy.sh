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

#----LOAD ENV VARS FROM INPUT FILE----#
if [ -z "$1" ]; then
    printf "Usage: ./destroy.sh <path-to-json-file>\n"
    exit 1
fi
if [ ! -f "$1" ]; then
    printf "$1 does not exist, exiting\n"
    exit 1
fi
CLUSTER_NAME=$(cat $1 | jq -r '.CLUSTER_NAME')
REGION=$(cat $1 | jq -r '.REGION')

#----VALIDATE ENV VARS----#
# Validate that we have all required env vars and exit with a failure if any are missing
missing=0


if [ "$missing" -ne 0 ]; then
    exit $missing
fi

if [ ! -z "$CLUSTER_NAME" ]; then
    RESOURCE_NAME="$CLUSTER_NAME-$RANDOM_IDENTIFIER"
    printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"
else
    printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"
fi


#----VERIFY EKSCTL CLI----#
if [ -z "$(which eksctl)" ]; then
    printf "${RED}Could not find the eksctl cli, exiting.  Try running ./install.sh.${CLEAR}\n"
    exit 1
fi



#----DELETE EKS CLUSTER----#
printf "${BLUE}Deleting the EKS cluster named ${CLUSTER_NAME}.${CLEAR}\n"

printf "${YELLOW}"
echo "y" | eksctl delete cluster --name ${CLUSTER_NAME} --region=${REGION}
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to delete EKS cluster ${CLUSTER_NAME}, exiting${CLEAR}\n"
    exit 1
fi
printf "${CLEAR}"
printf "${GREEN}Successfully cleaned up the EKS cluster named ${CLUSTER_NAME}.${CLEAR}\n"
