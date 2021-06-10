#!/bin/bash

# ROSA Provision based loosely on https://docs.openshift.com/rosa/rosa_getting_started/rosa-setting-up-environment.html

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

# Handle MacOS being incapable of tr, grep, and others
export LC_ALL=C

# Ensure we fail out if something goes wrong
set -e

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

# Default to us-east-1
AWS_REGION=${AWS_REGION:-"us-east-1"}

# Default to latest (empty)
OCP_VERSION=${OCP_VERSION:-""}

# Default to m5.xlarge
AWS_WORKER_TYPE=${AWS_WORKER_TYPE:-"m5.xlarge"}

# Default to 3 workers
AWS_WORKER_COUNT=${AWS_WORKER_COUNT:-"3"}

# Default to "stable"
CHANNEL_GROUP=${CHANNEL_GROUP:-"stable"}


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


#----GENERATE RESOURCE NAME----#
if [ ! -z "$CLUSTER_NAME" ]; then
    RESOURCE_NAME="$CLUSTER_NAME"
    printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"
else
    printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"
fi
STATE_FILE=$PWD/${RESOURCE_NAME}.json


#----LOG IN----#
printf "${BLUE}Logging in to the 'rosa' cli.${CLEAR}\n"
printf "${YELLOW}"
${ROSA} login --token=${ROSA_TOKEN}
printf "${CLEAR}"


#----VERIFY PERMISSIONS AND QUOTA-----#
printf "${BLUE}Verifying Permissions on AWS Account.${CLEAR}\n"
printf "${YELLOW}"
${ROSA} verify permissions
printf "${CLEAR}"
printf "${BLUE}Verifying Quota in region ${AWS_REGION}.${CLEAR}\n"
printf "${YELLOW}"
${ROSA} verify quota --region=${AWS_REGION}
printf "${CLEAR}"


#-----RUN ROSA INIT-----#
printf "${BLUE}Run 'rosa init' to prepare account.${CLEAR}\n"
printf "${YELLOW}"
${ROSA} init
printf "${CLEAR}"


#-----LOG THE PROVISIONER-----#
printf "${BLUE}Cluster will be provisioned as:${CLEAR}\n"
printf "${BLUE}"
${ROSA} whoami
printf "${CLEAR}"


#----WRITE INITIAL STATE FILE----#
printf "${BLUE}Writing inital state before starting provision.${CLEAR}"
if [[ ! -f ${STATE_FILE} ]]; then
    echo "{}" > ${STATE_FILE}
fi
jq --arg cluster_name "${RESOURCE_NAME}" '. + {CLUSTER_NAME: $cluster_name}' ${STATE_FILE} > .tmp; mv .tmp ${STATE_FILE};
jq --arg region "${AWS_REGION}" '. + {REGION: $region}' ${STATE_FILE} > .tmp; mv .tmp ${STATE_FILE};
jq --arg platform "rosa" '. + {PLATFORM: $platform}' ${STATE_FILE} > .tmp; mv .tmp ${STATE_FILE};
# Load account ID and log in JSON to ensure that cleanup is successful if provision fails
aws_account_id=$(${ROSA} whoami | grep "AWS Account ID:" | sed -n "s/AWS Account ID:[ ]*\(.*\)/\1/p")
jq --arg aws_account_id "${aws_account_id}" '. + {AWS_ACCOUNT_ID: $aws_account_id}' ${STATE_FILE} > .tmp; mv .tmp ${STATE_FILE};

#-----PROVISION CLUSTER AND WATCH LOGS-----#
printf "${BLUE}Provisioning the ROSA cluster ${RESOURCE_NAME} in ${AWS_REGION}.${CLEAR}\n"
printf "${YELLOW}"
${ROSA} create cluster \
    --cluster-name=${RESOURCE_NAME} \
    --region=${AWS_REGION} \
    --version=${OCP_VERSION} \
    --compute-machine-type=${AWS_WORKER_TYPE} \
    --compute-nodes=${AWS_WORKER_COUNT} \
    --channel-group=${CHANNEL_GROUP} \
    --multi-az \
    --watch \
    --yes
printf "${CLEAR}"


#-----EXTRACT DETAILS-----#
api_url=$(${ROSA} describe cluster --cluster=${RESOURCE_NAME} | grep "API URL:" | sed -n "s/API URL:[ ]*\(.*\)/\1/p")
console_url=$(${ROSA} describe cluster --cluster=${RESOURCE_NAME} | grep "Console URL:" | sed -n "s/Console URL:[ ]*\(.*\)/\1/p")
# Update account ID logged earlier to match that of the cluster (just in case)
aws_account_id=$(${ROSA} describe cluster --cluster=${RESOURCE_NAME} | grep "AWS Account:" | sed -n "s/AWS Account:[ ]*\(.*\)/\1/p")


#-----CONFIGURE AUTH-----#
printf "${BLUE}Creating an admin user.${CLEAR}\n"
${ROSA} create admin --cluster=${RESOURCE_NAME} > .tmp_creds
username=$(cat .tmp_creds | grep "username" | sed -n "s/.*--username[ ]*\([^ ]*\)[ ]*.*/\1/p")
password=$(cat .tmp_creds | grep "password" | sed -n "s/.*--password[ ]*\([^ ]*\)[ ]*.*/\1/p")
rm -f .tmp_creds


#-----DUMP STATE FILE AND PRINT SUCCESS----#
jq --arg console_url "${console_url}" '. + {CONSOLE_URL: $console_url}' ${STATE_FILE} > .tmp; mv .tmp ${STATE_FILE};
jq --arg api_url "${api_url}" '. + {API_URL: $api_url}' ${STATE_FILE} > .tmp; mv .tmp ${STATE_FILE};
jq --arg aws_account_id "${aws_account_id}" '. + {AWS_ACCOUNT_ID: $aws_account_id}' ${STATE_FILE} > .tmp; mv .tmp ${STATE_FILE};
jq --arg username "${username}" '. + {USERNAME: $username}' ${STATE_FILE} > .tmp; mv .tmp ${STATE_FILE};
jq --arg password "${password}" '. + {PASSWORD: $password}' ${STATE_FILE} > .tmp; mv .tmp ${STATE_FILE};
printf "${GREEN}ROSA cluster named ${RESOURCE_NAME} provisioned successfully.\n${CLEAR}"
printf "${GREEN}Console URL: ${console_url}\n${CLEAR}"
printf "${GREEN}API URL: ${api_url}\n${CLEAR}"
printf "${GREEN}Username: ${username}\n${CLEAR}"
printf "${GREEN}Password: *****\n${CLEAR}"
printf "${GREEN}Full Password and username can be found in ${STATE_FILE}\n${CLEAR}"
printf "${GREEN}To destroy this cluster run './destroy.sh ${STATE_FILE}'\n${CLEAR}"
