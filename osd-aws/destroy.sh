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
YAML_DIR=`dirname $1`
YAML_FILE=`basename $1 .json`
IDP_YAML_FILENAME=$YAML_DIR/$YAML_FILE.yaml
if [ ! -f "$IDP_YAML_FILENAME" ]; then
    printf "$IDP_YAML_FILENAME does not exist, exiting\n"
    exit 1
fi

CLUSTER_NAME=$(cat $1 | jq -r '.CLUSTER_NAME')
CLUSTER_ID=$(cat $1 | jq -r '.CLUSTER_ID')
REGION=$(cat $1 | jq -r '.REGION')
OCM_URL=$(cat $1 | jq -r '.OCM_URL')

#----VALIDATE ENV VARS----#
# Validate that we have all required env vars and exit with a failure if any are missing
missing=0

if [ -z "$OCM_TOKEN" ]; then
    printf "${RED}OCM_TOKEN env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ "$missing" -ne 0 ]; then
    exit $missing
fi


#----VERIFY ocm CLI----#
if [ -z "$(which ocm)" ]; then
    printf "${RED}Could not find the ocm cli, exiting.  Try running ./install.sh.${CLEAR}\n"
    exit 1
fi

#----SIGN IN TO ocm----#
if [ -f ~/.ocm.json ]; then
    REFRESH_TOKEN=`cat ~/.ocm.json | jq -r '.refresh_token'`
    CLIENT_ID=`cat ~/.ocm.json | jq -r '.client_id'`
    curl --silent https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token -d grant_type=refresh_token -d client_id=$CLIENT_ID -d refresh_token=$REFRESH_TOKEN > /dev/null
else
    ocm login --token=$OCM_TOKEN --url $OCM_URL
fi

#----DELETE OCM-AWS CLUSTER----#
printf "${BLUE}Deleting the OCM-AWS cluster named ${CLUSTER_NAME}.${CLEAR}\n"

printf "${YELLOW}"
ocm delete /api/clusters_mgmt/v1/clusters/$CLUSTER_ID
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to delete cluster ${CLUSTER_NAME}, exiting${CLEAR}\n"
    exit 1
fi

#----DELETE IDP CONFIGURATION ----#
printf "${BLUE}Deleting the IDP configuration.${CLEAR}\n"

oc login --token=$IDP_SERVICE_ACCOUNT_TOKEN --server=$IDP_ISSUER_LOGIN_SERVER
oc delete -f $IDP_YAML_FILENAME
oc logout

printf "${CLEAR}"
printf "${GREEN}Successfully cleaned up the cluster named ${CLUSTER_NAME}.${CLEAR}\n"
