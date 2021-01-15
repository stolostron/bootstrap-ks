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
IBMCLOUD_REGION=${IBMCLOUD_REGION:-"us-east"}
IBMCLOUD_ZONE=${IBMCLOUD_ZONE:-"dal10"}
IKS_DEFAULT_FLAVOR="u3c.2x4.encrypted"
ROKS_DEFAULT_FLAVOR="b3c.4x16.encrypted"
FLAVOR=${FLAVOR:-""}
IKS_WORKER_COUNT=${IKS_WORKER_COUNT:-"3"}
ROKS=${ROKS:-false}
KUBERNETES_VERSION_OVERRIDE=${KUBERNETES_VERSION_OVERRIDE:-""}

# Set label to use for common messages
if [[ "${ROKS}" == "true" ]]; then
  IKS_LABEL_MSG="ROKS"
else
  IKS_LABEL_MSG="IKS"
fi

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

if [ ! -z "$CLUSTER_NAME" ]; then
    RESOURCE_NAME="$CLUSTER_NAME-$RANDOM_IDENTIFIER"
    printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"
else
    printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"
fi


#----VERIFY IBMCLOUD CLI----#
if [ -z "$(which ibmcloud)" ]; then
    printf "${RED}Could not find the ibmcloud cli, exiting.  Try running ./install.sh.\n"
    exit 1
fi


#----LOG IN----#
# Log in and optionally choose a specific subscription
ibmcloud login --apikey $IBMCLOUD_APIKEY -r $IBMCLOUD_REGION
if [ "$?" -ne 0 ]; then
    printf "${RED}ibmcloud cli login failed, check credentials. Exiting.${CLEAR}\n"
    exit 1
fi

printf "${BLUE}Using subscription:${CLEAR}\n"
printf "${YELLOW}"
ibmcloud account show
printf "${CLEAR}"


#----DETECT PUBLIC AND PRIVATE VLAN IF PRESENT----#
# get the vlan list, filter on type, grab the first one, and grab the first column of that entry (the ID)
PRIVATE_VLAN=$(ibmcloud ks vlan ls --zone ${IBMCLOUD_ZONE} -s | grep "private" | head -n 1 | awk '{print $1}')
PUBLIC_VLAN=$(ibmcloud ks vlan ls --zone ${IBMCLOUD_ZONE} -s | grep "public" | head -n 1 | awk '{print $1}')


#----DETECT LATEST KUBERNETES VERSION IF NOT OVERRIDDEN, SET FLAVOR APPROPRIATELY----#
if [ -z "${KUBERNETES_VERSION_OVERRIDE}" ]; then
    if [[ "${ROKS}" == "true" ]]; then
        printf "${BLUE}Detecting default ROKS version to use.${CLEAR}\n"
        KUBERNETES_VERSION=$(ibmcloud ks versions --show-version OPENSHIFT -s | grep "(default)" | sed -n "s/\([a-zA-Z0-9]*\)[[:space:]]*(default)/\1/p")
        NAME_SUFFIX="roks"
        if [ -z $FLAVOR ]; then
            FLAVOR=$ROKS_DEFAULT_FLAVOR
        fi
    else
        printf "${BLUE}Detecting default Kubernetes version to use.${CLEAR}\n"
        KUBERNETES_VERSION=$(ibmcloud ks versions --show-version KUBERNETES -s | grep "(default)" | sed -n "s/\([a-zA-Z0-9]*\)[[:space:]]*(default)/\1/p")
        NAME_SUFFIX="iks"
        if [ -z $FLAVOR ]; then
            FLAVOR=$IKS_DEFAULT_FLAVOR
        fi
    fi
    if [ -z "${KUBERNETES_VERSION}" ]; then
        printf "${RED}Failed to detect kubernetes version, empty result returned from filtered ibmcloud ks versions, is there a default version? Exiting.${CLEAR}\n"
        exit 1
    fi
else
    printf "${BLUE}Using KUBERNETES_VERSION_OVERRIDE as the ${IKS_LABEL_MSG} version.${CLEAR}\n"
    KUBERNETES_VERSION="${KUBERNETES_VERSION_OVERRIDE}"
    if [ -z "${KUBERNETES_VERSION}" ]; then
        printf "${RED}Failed to validate kubernetes version '${KUBERNETES_VERSION}', please verify that the specified version is available via 'ibmcloud ks versions', exiting.${CLEAR}\n"
        exit 1
    fi

    # detect flavor based on regex check for the word "openshift", which is in the name of all openshift versions on iks
    if [[ "${KUBERNETES_VERSION}" =~ *openshift* ]]; then
        FLAVOR=$ROKS_DEFAULT_FLAVOR
        NAME_SUFFIX="roks"
    else
        FLAVOR=$IKS_DEFAULT_FLAVOR
        NAME_SUFFIX="iks"
    fi
fi
printf "${BLUE}Using version ${KUBERNETES_VERSION} for ${IKS_LABEL_MSG} cluster.  Nodes will be flavor ${FLAVOR}.${CLEAR}\n"


#----CREATE IKS/ROKS CLUSTER----#
IKS_CLUSTER_NAME="${RESOURCE_NAME}-${NAME_SUFFIX}"
printf "${BLUE}Creating an ${IKS_LABEL_MSG} cluster named ${IKS_CLUSTER_NAME}.${CLEAR}\n"
ibmcloud ks cluster create classic \
    --name ${IKS_CLUSTER_NAME} \
    --flavor ${FLAVOR} \
    --workers ${IKS_WORKER_COUNT} \
    --zone ${IBMCLOUD_ZONE} \
    --version ${KUBERNETES_VERSION} $(if [ ! -z $PRIVATE_VLAN ]; then echo "--private-vlan ${PRIVATE_VLAN}"; fi) $(if [ ! -z $PUBLIC_VLAN ]; then echo "--public-vlan ${PUBLIC_VLAN}"; fi)

if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to provision ${IKS_LABEL_MSG} cluster. See error above. Exiting${CLEAR}\n"
    exit 1
fi

TIMEOUT=${TIMEOUT:-"2700"}
printf "${BLUE}Polling for $TIMEOUT seconds for the ${IKS_LABEL_MSG} cluster to be ready.${CLEAR}\n"
acc=0
cluster_status=$(ibmcloud ks cluster get --cluster ${IKS_CLUSTER_NAME} --json | jq -r '.state')
while [[ "${cluster_status}" != "normal" ]]; do
    sleep 30
    acc=$((acc+30))
    printf "${YELLOW}(${acc}/${TIMEOUT}) Waiting for cluster to reach 'normal' status, current status is '${cluster_status}'.${CLEAR}\n"
    if [ "$acc" -ge "$TIMEOUT" ]; then
        printf "${RED}Timed out waiting for ${IKS_LABEL_MSG} cluster to report 'normal' status.  Final status was $cluster_status.\n${CLEAR}";
        cat > $(pwd)/${IKS_CLUSTER_NAME}.json <<EOF
{
    "CLUSTER_NAME": "${IKS_CLUSTER_NAME}",
    "RESOURCE_NAME": "${RESOURCE_NAME}",
    "REGION": "${IBMCLOUD_REGION}",
    "PLATFORM": "IBMCLOUD"
}
EOF
        printf "${RED} Wrote results to $(pwd)/${IKS_CLUSTER_NAME}.json for use with destroy.sh"
        exit 1;
    fi
    cluster_status=$(ibmcloud ks cluster get --cluster ${IKS_CLUSTER_NAME} --json | jq -r '.state')
done;
printf "${GREEN}Cluster reached 'normal' status. Successfully provisioned ${IKS_LABEL_MSG} cluster ${IKS_CLUSTER_NAME}.${CLEAR}\n"


#----EXTRACTING KUBECONFIG----#
printf "${BLUE}Getting Kubeconfig for the cluster named ${IKS_CLUSTER_NAME}.${CLEAR}\n"
printf "${YELLOW}"
ibmcloud ks cluster config --cluster ${IKS_CLUSTER_NAME} --admin --output yaml > $(pwd)/${IKS_CLUSTER_NAME}.kubeconfig
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to get credentials for ${IKS_LABEL_MSG} cluster ${IKS_CLUSTER_NAME}, complaining and continuing${CLEAR}\n"
    exit 1
fi
printf "${GREEN}You can find your kubeconfig file for this cluster in $(pwd)/${IKS_CLUSTER_NAME}.kubeconfig.\n${CLEAR}"
printf "${CLEAR}"


#-----DUMP STATE FILE----#
cat > $(pwd)/${IKS_CLUSTER_NAME}.json <<EOF
{
    "CLUSTER_NAME": "${IKS_CLUSTER_NAME}",
    "RESOURCE_NAME": "${RESOURCE_NAME}",
    "REGION": "${IBMCLOUD_REGION}",
    "PLATFORM": "IBMCLOUD"
}
EOF
printf "${GREEN}${IKS_LABEL_MSG} cluster provision successful.  Cluster named ${IKS_CLUSTER_NAME} created. \n"
printf "State file saved for cleanup in $(pwd)/${IKS_CLUSTER_NAME}.json${CLEAR}\n"
