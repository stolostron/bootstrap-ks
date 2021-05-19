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
RESOURCE_GROUP_NAME=$(cat $1 | jq -r '.RESOURCE_GROUP_NAME')
CLUSTER_NAME=$(cat $1 | jq -r '.CLUSTER_NAME')
REGION=$(cat $1 | jq -r '.REGION')
AZURE_SUBSCRIPTION_ID=$(cat $1 | jq -r '.SUBSCRIPTION')
PLATFORM=$(cat $1 | jq -r '.PLATFORM')
AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME=$(cat $1 | jq -r '.AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME')
AZURE_BASE_DOMAIN=$(cat $1 | jq -r '.AZURE_BASE_DOMAIN')
USERNAME=$(cat $1 | jq -r '.USERNAME')
PASSWORD=$(cat $1 | jq -r '.PASSWORD')
CONSOLE_URL=$(cat $1 | jq -r '.CONSOLE_URL')

# Set a skipped flag that we'll set if we skip any deletions.  Used to skip deletion of state files.
skipped=0


#----VALIDATE ENV VARS----#
# Validate that we have all required env vars and exit with a failure if any are missing
missing=0

if [ -z "$AZURE_PASS" ]; then
    printf "${RED}AZURE_PASS env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ -z "$AZURE_USER" ]; then
    printf "${RED}AZURE_USER env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ -z "$AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME" ]; then
    printf "${RED}AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ -z "$AZURE_BASE_DOMAIN" ]; then
    printf "${RED}AZURE_BASE_DOMAIN env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ -z "$OCP_PULL_SECRET_FILE" ]; then
    printf "${RED}OCP_PULL_SECRET_FILE env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ "$missing" -ne 0 ]; then
    exit $missing
fi


#----LOG IN----#
# Log in and optionally choose a specific subscription
az login -u "$AZURE_USER" -p "$AZURE_PASS" &> /dev/null
if [ "$?" -ne 0 ]; then
    printf "${RED}Azure login failed, check credentials. Exiting.${CLEAR}\n"
    exit 1
fi

if [[ "$AZURE_SUBSCRIPTION_ID" && "$AZURE_SUBSCRIPTION_ID" != "null" ]]; then
    az account set --subscription $AZURE_SUBSCRIPTION_ID
    if [ "$?" -ne 0 ]; then
        printf "${RED}Unable to set azure subscription, az account set --subscription $AZURE_SUBSCRIPTION_ID returned non-zero.${CLEAR}\n"
        printf "${RED}Exiting to avoid the creation of a cluster in the wrong account.${CLEAR}\n"
        exit 1
    fi
fi

printf "${BLUE}Using subscription:${CLEAR}\n"
printf "${YELLOW}"
SUBSCRIPTION=$(az account show | jq -r '.id')
if [ -z "${SUBSCRIPTION}" ]; then
    printf "${RED}Couldn't detect a subscription to be used, exiting.${CLEAR}"
    exit 1
fi
az account show
printf "${CLEAR}"


#----DELETE NS, ARO CLUSTER, VNETS, AND DNS ZONES----#
if [[ "${RESOURCE_GROUP_NAME}" != "null" ]]; then
    printf "${BLUE}Deleting the resource group ${RESOURCE_GROUP_NAME} and related DNS Zones, VNets, and ARO Cluster ${CLUSTER_NAME}.${CLEAR}\n"
    printf "${YELLOW}"
    az group delete -n ${RESOURCE_GROUP_NAME} -y;
    printf "${CLEAR}"
else
    printf "${RED}Couldn't find RESOURCE_GROUP_NAME key in ${1}, skipping resource group deletion.${CLEAR}\n"
    skipped=1
fi


#----DELETE BASE DOMAIN RECORD SETS---#
if [[ "${AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME}" != "null" && "${AZURE_BASE_DOMAIN}" != "null" ]]; then
    printf "${BLUE}Deleting the record sets for the cluster base domain in the ${AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME} resource group.${CLEAR}\n"
    printf "${YELLOW}"
    az network dns record-set ns delete \
        -g ${AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME} \
        -z ${AZURE_BASE_DOMAIN} \
        -n ${CLUSTER_NAME} \
        -y;
    printf "${CLEAR}"
else
    printf "${RED}Couldn't find AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME and AZURE_BASE_DOMAIN in ${1}, skipping record set deletion.${CLEAR}\n"
    skipped=1
fi


#----SUCCEED IF WE MADE IT THIS FAR----#
if [[ "$skipped" ]]; then
    printf "${GREEN}Successfully deleted the ARO Cluster ${CLUSTER_NAME} and related resources.  Deleting state and creds files.${CLEAR}\n"
    rm -f $1
    if [[ -f "${CLUSTER_NAME}" ]]; then
        rm -f ${CLUSTER_NAME}.creds.json;
    fi
else
    printf "${RED}Some details were missing from the state file and were skipped, we won't clean up $1 or ${CLUSTER_NAME}.creds.json.${CLEAR}\n"
    printf "${BLUE}If you were trying to clean up a partial failed provision, this probably isn't a problem, so you can delete $1 and ${CLUSTER_NAME}.${CLEAR}\n"
fi
