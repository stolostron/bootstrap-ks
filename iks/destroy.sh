#!/bin/bash

# Color codes for bash output
BLUE='\e[36m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CLEAR='\e[39m'

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
RESOURCE_NAME=$(cat $1 | jq -r '.RESOURCE_NAME')


#----VALIDATE ENV VARS----#
# Validate that we have all required env vars and exit with a failure if any are missing
missing=0

if [ -z "$IBMCLOUD_APIKEY" ]; then
    printf "${RED}IBMCLOUD_APIKEY env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ "$missing" -ne 0 ]; then
    exit $missing
fi


#----LOG IN----#
# Log in and optionally choose a specific subscription
ibmcloud login --apikey $IBMCLOUD_APIKEY -r $REGION
if [ "$?" -ne 0 ]; then
    printf "${RED}ibmcloud cli login failed, check credentials. Exiting.${CLEAR}\n"
    exit 1
fi

printf "${BLUE}Using subscription:${CLEAR}\n"
printf "${YELLOW}"
ibmcloud account show
printf "${CLEAR}"


#----DELETE IKS CLUSTER----#
printf "${BLUE}Deleting the IKS cluster named ${CLUSTER_NAME}.${CLEAR}\n"

printf "${YELLOW}"
ibmcloud ks cluster rm --cluster ${CLUSTER_NAME} -f --force-delete-storage -s
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to delete IKS cluster ${CLUSTER_NAME}, exiting${CLEAR}\n"
    exit 1
fi
printf "${CLEAR}"
printf "${GREEN}Successfully cleaned up the IKS cluster named ${CLUSTER_NAME}.${CLEAR}\n"
