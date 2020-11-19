#!/bin/bash

# Color codes for bash output
BLUE='\e[36m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CLEAR='\e[39m'

# Handle MacOS being incapable of tr, grep, and others
export LC_ALL=C

#----DEFAULTS----#
# Generate a 5-digit random cluster identifier for resource tagging purposes
RANDOM_IDENTIFIER=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 5 ; echo '')
SHORTNAME=$(echo $USER | head -c 8)

# Generate a default resource name
RESOURCE_NAME="$SHORTNAME-$RANDOM_IDENTIFIER"
NAME_SUFFIX="eks"

# Default to us-east-1
EKS_REGION=${EKS_REGION:-"us-east-1"}
EKS_NODE_COUNT=${EKS_NODE_COUNT:-"3"}
# Optional - defaults is to auto-select
EKS_ZONES=${EKS_ZONES:-""}


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


#----VERIFY Amazon EKS CLI----#
if [ -z "$(which eksctl)" ]; then
    printf "${RED}Could not find the eksctl cli, exiting.  Try running ./install.sh.${CLEAR}\n"
    exit 1
fi




#----CREATE EKS CLUSTER----#
EKS_CLUSTER_NAME="${RESOURCE_NAME}-${NAME_SUFFIX}"
printf "${BLUE}Creating an EKS cluster named ${EKS_CLUSTER_NAME}.${CLEAR}\n"
printf "${YELLOW}"

OPTIONAL_PARAMS=""
if [ ! -z "$EKS_ZONES" ]; then
  OPTIONAL_PARAMS=$"${OPTIONAL_PARAMS} --zones ${EKS_ZONES} "
fi

eksctl create cluster --name "${EKS_CLUSTER_NAME}" --nodes "${EKS_NODE_COUNT}" --region "${EKS_REGION}" --kubeconfig "$(pwd)/${EKS_CLUSTER_NAME}.kubeconfig" ${OPTIONAL_PARAMS}
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to provision EKS cluster. See error above. Exiting${CLEAR}\n"
    exit 1
fi
printf "${GREEN}Successfully provisioned EKS cluster ${EKS_CLUSTER_NAME}.${CLEAR}\n"


#----EXTRACTING KUBECONFIG----#
printf "${GREEN}You can find your kubeconfig file for this cluster in $(pwd)/${EKS_CLUSTER_NAME}.kubeconfig\n${CLEAR}"
printf "${CLEAR}"


#-----DUMP STATE FILE----#
cat > $(pwd)/${EKS_CLUSTER_NAME}.json <<EOF
{
    "CLUSTER_NAME": "${EKS_CLUSTER_NAME}",
    "REGION": "${EKS_REGION}",
    "PLATFORM": "EKS"
}
EOF

printf "${GREEN}EKS cluster provision successful.  Cluster named ${EKS_CLUSTER_NAME} created. \n"
printf "State file saved for cleanup in $(pwd)/${EKS_CLUSTER_NAME}.json${CLEAR}\n"
