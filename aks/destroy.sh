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
RESOURCE_GROUP_NAME=$(cat $1 | jq -r '.RESOURCE_GROUP_NAME')
SUBSCRIPTION=$(cat $1 | jq -r '.SUBSCRIPTION')

# Default to disable the service principal login
SERVICE_PRINCIPAL=${SERVICE_PRINCIPAL:-"false"}

#----LOG IN----#
# Log in and optionally choose a specific subscription
if [ $SERVICE_PRINCIPAL == "true" ]; then
    if [ -z "$CLIENT_ID" ]; then
        printf "${RED}CLIENT_ID env var not set. flagging for exit.${CLEAR}\n"
        exit 1
    fi
    if [ -z "$CLIENT_SECRET" ]; then
        printf "${RED}CLIENT_SECRET env var not set. flagging for exit.${CLEAR}\n"
        exit 1
    fi
    if [ -z "$TENANT_ID" ]; then
        printf "${RED}TENANT_ID env var not set. flagging for exit.${CLEAR}\n"
        exit 1
    fi    
    az login --service-principal -u "$CLIENT_ID" -p "$CLIENT_SECRET" -t "$TENANT_ID" > /dev/null
    if [ "$?" -ne 0 ]; then
        printf "${RED}Azure login failed, check credentials. Exiting.${CLEAR}\n"
        exit 1
    fi
else
    if [ -z "$AZURE_PASS" ]; then
        printf "${RED}AZURE_PASS env var not set. flagging for exit.${CLEAR}\n"
        exit 1
    fi
    if [ -z "$AZURE_USER" ]; then
        printf "${RED}AZURE_USER env var not set. flagging for exit.${CLEAR}\n"
        exit 1
    fi
    az login -u "$AZURE_USER" -p "$AZURE_PASS" > /dev/null
    if [ "$?" -ne 0 ]; then
        printf "${RED}Azure login failed, check credentials. Exiting.${CLEAR}\n"
        exit 1
    fi
fi

if [ ! -z "$SUBSCRIPTION" ]; then
    az account set --subscription $SUBSCRIPTION
    if [ "$?" -ne 0 ]; then
        printf "${RED}Unable to set azure subscription, az account set --subscription $SUBSCRIPTION returned non-zero.${CLEAR}\n"
        printf "${RED}Exiting to avoid the creation of a cluster in the wrong account.${CLEAR}\n"
        exit 1
    fi
fi

printf "${BLUE}Using subscription:${CLEAR}\n"
printf "${YELLOW}"
az account show
printf "${CLEAR}"


#----DELETE AKS CLUSTER----#
printf "${BLUE}Deleting the AKS cluster named ${CLUSTER_NAME} in resource group $RESOURCE_GROUP_NAME from subscription $SUBSCRIPTION in region $REGION.${CLEAR}\n"

printf "${YELLOW}"
az aks delete --resource-group "${RESOURCE_GROUP_NAME}" --name "${CLUSTER_NAME}" --subscription $SUBSCRIPTION --yes
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to delete AKS cluster ${CLUSTER_NAME}, exiting${CLEAR}\n"
    exit 1
fi
printf "${CLEAR}"


#----DELETE RESOURCE GROUP----#
printf "${BLUE}Deleting the resource group named $RESOURCE_GROUP_NAME from subscription $SUBSCRIPTION in region $REGION.${CLEAR}\n"

printf "${YELLOW}"
az group delete --name "${RESOURCE_GROUP_NAME}" --subscription $SUBSCRIPTION --yes
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to delete resource group ${RESOURCE_GROUP_NAME}, exiting${CLEAR}\n"
    exit 1
fi
printf "${CLEAR}"
