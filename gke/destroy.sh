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

GCLOUD_CREDS_FILE=${GCLOUD_CREDS_FILE:-"$HOME/.gcp/osServiceAccount.json"}

CLUSTER_NAME=$(cat $1 | jq -r '.CLUSTER_NAME')
REGION=$(cat $1 | jq -r '.REGION')

#----VALIDATE ENV VARS----#
# Validate that we have all required env vars and exit with a failure if any are missing
missing=0

if [ -z "$GCLOUD_CREDS_FILE" ]; then
    printf "${RED}GCLOUD_CREDS_FILE env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ -z "$GCLOUD_PROJECT_ID" ]; then
    printf "${RED}GCLOUD_PROJECT_ID env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ "$missing" -ne 0 ]; then
    exit $missing
fi

if [ ! -z "$CLUSTER_NAME" ]; then
    RESOURCE_NAME="$CLUSTER_NAME-$RANDOM_IDENTIFIER"
    printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"
else
    printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"
fi


#----VERIFY GCLOUD CLI----#
if [ -z "$(which gcloud)" ]; then
    printf "${RED}Could not find the gcloud cli, exiting.  Try running ./install.sh.${CLEAR}\n"
    exit 1
fi


#----LOG IN----#
# Log in and optionally choose a specific subscription
printf "${BLUE}Logging in to the gcloud cli.${CLEAR}\n"
#gcloud auth activate-service-account --key-file ~/.secrets/gc-acm-cicd.json
gcloud auth activate-service-account --key-file $GCLOUD_CREDS_FILE
if [ "$?" -ne 0 ]; then
    printf "${RED}gcloud cli login failed, check credentials. Exiting.${CLEAR}\n"
    exit 1
fi

printf "${BLUE}Setting the gcloud cli's project id to ${GCLOUD_PROJECT_ID}.${CLEAR}\n"
gcloud config set project ${GCLOUD_PROJECT_ID}


#----DELETE GKE CLUSTER----#
printf "${BLUE}Deleting the GKE cluster named ${CLUSTER_NAME}.${CLEAR}\n"

printf "${YELLOW}"
gcloud container clusters delete ${CLUSTER_NAME} --region=${REGION} --quiet
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to delete GKE cluster ${CLUSTER_NAME}, exiting${CLEAR}\n"
    exit 1
fi
printf "${CLEAR}"
printf "${GREEN}Successfully cleaned up the GKE cluster named ${CLUSTER_NAME}.${CLEAR}\n"
