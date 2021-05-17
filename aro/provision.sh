#!/bin/bash

# AKS Provision loosely based on:
# https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster

# Color codes for bash output
BLUE='\e[36m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CLEAR='\e[39m'

# Handle MacOS being incapable of tr, grep, and others
export LC_ALL=C

# Ensure we fail out if something goes wrong
set -e

#----DEFAULTS----#
# Generate a 5-digit random cluster identifier for resource tagging purposes
RANDOM_IDENTIFIER=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 5 ; echo '')
# Ensure USER has a value
if [ -z "$JENKINS_HOME" ]; then
  USER=${USER:-"unknown"}
else
  USER=${USER:-"jenkins"}
fi

SHORTNAME=$(echo $USER | head -c 8)

# Generate a default resource name
RESOURCE_NAME="$SHORTNAME-$RANDOM_IDENTIFIER"

# Default to eastus
AZURE_REGION=${AZURE_REGION:-"eastus"}

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


#----GENERATE RESOURCE NAME----#
if [ ! -z "$CLUSTER_NAME" ]; then
    RESOURCE_NAME="$CLUSTER_NAME-$RANDOM_IDENTIFIER"
    printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"
else
    printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"
fi


#----LOG IN----#
# Log in and optionally choose a specific subscription
az login -u "$AZURE_USER" -p "$AZURE_PASS" &> /dev/null
if [ "$?" -ne 0 ]; then
    printf "${RED}Azure login failed, check credentials. Exiting.${CLEAR}\n"
    exit 1
fi

if [ ! -z "$AZURE_SUBSCRIPTION_ID" ]; then
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


#----REGISTER RESOURCE PROVIDERS----#
printf "${BLUE}Enabling the Microsoft.RedHatOpenShift Resource Provider.${CLEAR}\n"
az provider register -n Microsoft.RedHatOpenShift --wait
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to register the Microsoft.RedHatOpenShift provider. Exiting.${CLEAR}\n"
    exit 1
fi
printf "${BLUE}Enabling the Microsoft.Compute Resource Provider.${CLEAR}\n"
az provider register -n Microsoft.Compute --wait
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to register the Microsoft.Compute provider. Exiting.${CLEAR}\n"
    exit 1
fi
printf "${BLUE}Enabling the Microsoft.Storage Resource Provider.${CLEAR}\n"
az provider register -n Microsoft.Storage --wait
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to register the Microsoft.Storage provider. Exiting.${CLEAR}\n"
    exit 1
fi
printf "${BLUE}Enabling the Microsoft.Authorization Resource Provider.${CLEAR}\n"
az provider register -n Microsoft.Authorization --wait
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to register the Microsoft.Authorization provider. Exiting.${CLEAR}\n"
    exit 1
fi


#----CREATE RESOURCE GROUP----#
RESOURCE_GROUP_NAME="${RESOURCE_NAME}-rg"
printf "${BLUE}Creating a resource group named ${RESOURCE_GROUP_NAME}.${CLEAR}\n"

printf "${YELLOW}"
az group create --name "${RESOURCE_GROUP_NAME}" --location "$AZURE_REGION" --subscription $SUBSCRIPTION
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to create resource group ${RESOURCE_GROUP_NAME}, exiting${CLEAR}\n"
    exit 1
fi
printf "${CLEAR}"


#----CREATE A VNET FOR THE CLUSTER----#
printf "${BLUE}Creating a virtual network named ${RESOURCE_NAME}-vnet.${CLEAR}\n"
printf "${YELLOW}"
az network vnet create \
    --location ${AZURE_REGION} \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${RESOURCE_NAME}-vnet \
    --address-prefixes 10.0.0.0/22;
printf "${CLEAR}"


#----CREATE A SUBNET FOR MASTERS----#
printf "${BLUE}Creating a subnet named master-subnet in ${RESOURCE_NAME}-vnet.${CLEAR}\n"
printf "${YELLOW}"
az network vnet subnet create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --vnet-name ${RESOURCE_NAME}-vnet \
    --name master-subnet \
    --address-prefixes 10.0.0.0/23 \
    --service-endpoints Microsoft.ContainerRegistry;
printf "${CLEAR}"


#----CREATE A SUBNET FOR WORKERS----#
printf "${BLUE}Creating a subnet named worker-subnet in ${RESOURCE_NAME}-vnet.${CLEAR}\n"
printf "${YELLOW}"
az network vnet subnet create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --vnet-name ${RESOURCE_NAME}-vnet \
    --name worker-subnet \
    --address-prefixes 10.0.2.0/23 \
    --service-endpoints Microsoft.ContainerRegistry;
printf "${CLEAR}"


#----DISABLE SUBNET PRIVATE ENDPOINT POLICIES ON MASTER SUBNET----#
printf "${BLUE}Disabling private endpoint policies on master-subnet.  ${CLEAR}\n"
printf "${YELLOW}"
az network vnet subnet update \
    --name master-subnet \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --vnet-name ${RESOURCE_NAME}-vnet \
    --disable-private-link-service-network-policies true;
printf "${CLEAR}"


#----CREATE A DNS ZONE FOR CLUSTER----#
printf "${BLUE}Creating a DNS Zone named ${RESOURCE_NAME}.az.red-chesterfield.com in ${RESOURCE_GROUP_NAME}.${CLEAR}\n"
printf "${YELLOW}"
az network dns zone create \
    -g ${RESOURCE_GROUP_NAME} \
    -n ${RESOURCE_NAME}.${AZURE_BASE_DOMAIN};
printf "${CLEAR}"


#----CREATE/MODIFY DNS RECORD SETS----#
printf "${BLUE}Creating nameserver records in ${AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME} for the domain ${RESOURCE_NAME}.az.red-chesterfield.com.${CLEAR}\n"
printf "${YELLOW}"
az network dns zone show -g ${RESOURCE_GROUP_NAME} -n ${RESOURCE_NAME}.${AZURE_BASE_DOMAIN} \
    | jq -r '.nameServers | .[]' \
    | xargs -L 1 az network dns record-set ns add-record -g $AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME -z $AZURE_BASE_DOMAIN -n ${RESOURCE_NAME} -d
printf "${CLEAR}"


#----CREATE ARO CLUSTER----#
printf "${BLUE}Creating the ARO Cluster ${RESOURCE_NAME} in the ${RESOURCE_GROUP_NAME} resource group.${CLEAR}\n"
printf "${YELLOW}"
az aro create \
    --location ${AZURE_REGION} \
    --resource-group $RESOURCE_GROUP_NAME \
    --name ${RESOURCE_NAME} \
    --vnet ${RESOURCE_NAME}-vnet \
    --master-subnet master-subnet \
    --worker-subnet worker-subnet \
    --domain=${RESOURCE_NAME}.${AZURE_BASE_DOMAIN} \
    --pull-secret @${OCP_PULL_SECRET_FILE};
printf "${CLEAR}"


#----CREATE API AND APPS RECORD SETS----#
printf "${BLUE}Creating record sets for ingress and api urls for the ${CLEAR}\n"
api_url=$(az aro show -n ${RESOURCE_NAME} -g ${RESOURCE_GROUP_NAME} --query '{api:apiserverProfile.ip}' | jq -r '.api')
ingress_url=$(az aro show -n ${RESOURCE_NAME} -g ${RESOURCE_GROUP_NAME} --query '{ingress:ingressProfiles[0].ip}' | jq -r '.ingress')
printf "${YELLOW}"
az network dns record-set a add-record -n api -g ${RESOURCE_GROUP_NAME} -z ${RESOURCE_NAME}.${AZURE_BASE_DOMAIN} -a ${api_url}
az network dns record-set a add-record -n *.apps -g ${RESOURCE_GROUP_NAME} -z ${RESOURCE_NAME}.${AZURE_BASE_DOMAIN} -a ${ingress_url}
printf "${CLEAR}"


#----EXRACT USERNAME AND PASS-----#
printf "${BLUE}Creating record sets for ingress and api urls for the ${CLEAR}\n"
username=$(az aro list-credentials --name ${RESOURCE_NAME} -g ${RESOURCE_GROUP_NAME} | jq -r '.kubeadminUsername')
password=$(az aro list-credentials --name ${RESOURCE_NAME} -g ${RESOURCE_GROUP_NAME} | jq -r '.kubeadminPassword')


#----EXTRACT CONSOLE URL----#
console_url=$(az aro show --name ${RESOURCE_NAME} -g ${RESOURCE_GROUP_NAME} --query "consoleProfile.url" -o tsv)


#-----DUMP STATE FILE, CREDS, AND PRINT SUCCESS----#
cat > ./${RESOURCE_NAME}.json <<EOF
{
    "RESOURCE_GROUP_NAME": "${RESOURCE_GROUP_NAME}",
    "CLUSTER_NAME": "${RESOURCE_NAME}",
    "REGION": "${AZURE_REGION}",
    "SUBSCRIPTION": "${SUBSCRIPTION}",
    "PLATFORM": "ARO",
    "AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME": "${AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME}",
    "AZURE_BASE_DOMAIN": "${AZURE_BASE_DOMAIN}",
    "USERNAME": "${username}",
    "PASSWORD": "${password}",
    "CONSOLE_URL": "${console_url}"
}
EOF
cat > ./${RESOURCE_NAME}.creds.json <<EOF
{
    "USERNAME": "${username}",
    "PASSWORD": "${password}",
    "CONSOLE_URL": "${console_url}"
}
EOF
printf "${GREEN}ARO cluster named ${RESOURCE_NAME} provisioned successfully.\n${CLEAR}"
printf "${GREEN}Console URL: ${console_url}\n${CLEAR}"
printf "${GREEN}Username: ${username}\n${CLEAR}"
printf "${GREEN}Password: *****\n${CLEAR}"
printf "${GREEN}Password and Credentials can be found in $(pwd)/${RESOURCE_NAME}.creds.json\n${CLEAR}"
printf "${GREEN}State file saved for cleanup in $(pwd)/${RESOURCE_NAME}.json\n${CLEAR}"
