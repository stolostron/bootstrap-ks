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

# Check for vendored or global 'rosa' cli
if [[ $(which rosa) ]]; then
    ROSA=$(which rosa)
elif [[ -x $PWD/vendor/rosa ]]; then
    ROSA=$PWD/vendor/rosa
else
    printf "${RED}'rosa' CLI not found globally or vendored, run install.sh to set up dependencies.${CLEAR}\n"
    exit 1
fi
printf "${BLUE}Using 'rosa' CLI installed at ${ROSA}${CLEAR}\n"

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
PLATFORM=$(cat $1 | jq -r '.PLATFORM')
USERNAME=$(cat $1 | jq -r '.USERNAME')
PASSWORD=$(cat $1 | jq -r '.PASSWORD')
CONSOLE_URL=$(cat $1 | jq -r '.CONSOLE_URL')
API_URL=$(cat $1 | jq -r '.API_URL')
AWS_ACCOUNT_ID=$(cat $1 | jq -r '.AWS_ACCOUNT_ID')

# Export AWS_REGION as it is used under the covers by the aws cli
export AWS_REGION=$(cat $1 | jq -r '.REGION')

# Set a skipped flag that we'll set if we skip any deletions.  Used to skip deletion of state files.
skipped=0

# Handle MacOS being incapable of tr, grep, and others
export LC_ALL=C

# Ensure we fail out if something goes wrong
set -e

#----VALIDATE ENV VARS----#
# Validate that we have all required env vars and exit with a failure if any are missing
missing=0

if [ -z "$ROSA_TOKEN" ]; then
    printf "${RED}ROSA_TOKEN env var not set. Find this token at https://cloud.redhat.com/openshift/token/rosa. Flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    printf "${RED}AWS_ACCESS_KEY_ID env var not set. Flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    printf "${RED}AWS_SECRET_ACCESS_KEY env var not set. Flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ "$missing" -ne 0 ]; then
    exit $missing
fi


#----LOG IN----#
printf "${BLUE}Logging in to the 'rosa' cli.${CLEAR}\n"
printf "${YELLOW}"
${ROSA} login --token=${ROSA_TOKEN}
printf "${CLEAR}"


#-----VALIDATE THE AWS ACCOUNT ID-----#
printf "${BLUE}Validate that the user is logged into the AWS account that hold the ${CLUSTER_NAME} cluster.${CLEAR}\n"
current_aws_id=$(${ROSA} whoami | grep "AWS Account ID:" | sed -n "s/AWS Account ID:[ ]*\(.*\)/\1/p")
if [[ "${current_aws_id}" != "${AWS_ACCOUNT_ID}" ]]; then
    printf "${YELLOW}The current AWS account ID (${current_aws_id}) doesn't match the ID of the account where ${CLUSTER_NAME} was created.${CLEAR}\n"
    printf "${YELLOW}Make sure you're logged in to the same account (ID: ${AWS_ACCOUNT_ID}) that was used to create ${CLUSTER_NAME} and re-run.${CLEAR}\n"
    printf "${RED}Exiting to avoid destroying the wrong cluster.${CLEAR}\n"
    exit 1
else
    printf "${YELLOW}Current AWS account ID (${current_aws_id}) matches the ID where ${CLUSTER_NAME} was provisioned (${AWS_ACCOUNT_ID}).${CLEAR}\n"
fi


#-----LOG THE DEPROVISIONER-----#
printf "${BLUE}Cluster will be deprovisioned as:${CLEAR}\n"
printf "${BLUE}"
${ROSA} whoami
printf "${CLEAR}"


#-----DELETE THE CLUSTER-----#
printf "${BLUE}Launching the cluster deprovision for ${CLUSTER_NAME}.${CLEAR}\n"
printf "${YELLOW}"
${ROSA} delete cluster --cluster=${CLUSTER_NAME} --yes --watch
printf "${CLEAR}"


#----SUCCEED IF WE MADE IT THIS FAR----#
printf "${GREEN}Successfully deleted the ROSA Cluster ${CLUSTER_NAME} and related resources.  Deleting state file.${CLEAR}\n"
rm -f $1
