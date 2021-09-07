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
NAME_SUFFIX="gcp"

# Default to eastus
GCLOUD_CREDS_FILE=${GCLOUD_CREDS_FILE:-"$HOME/.gcp/osServiceAccount.json"}
GCLOUD_REGION=${GCLOUD_REGION:-"us-east1"}
GCLOUD_NODE_COUNT=${GCLOUD_NODE_COUNT:-"3"}

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

export WORKDIR=$(pwd)
if [ -w ${WORKDIR} ]; then
  printf "${BLUE}Writing to current directory.${CLEAR}\n"
else
  export WORKDIR="/tmp"
fi
printf "${BLUE}Writing output files to ${WORKDIR}${CLEAR}\n"

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


#----CREATE GKE CLUSTER----#
GKE_CLUSTER_NAME="${RESOURCE_NAME}-${NAME_SUFFIX}"
export KUBECONFIG=${WORKDIR}/${CLUSTER_NAME}.kubeconfig
printf "${BLUE}Creating an GKE cluster named ${GKE_CLUSTER_NAME}.${CLEAR}\n"
printf "${YELLOW}"
gcloud container clusters create ${GKE_CLUSTER_NAME} --num-nodes=${GCLOUD_NODE_COUNT} --region="${GCLOUD_REGION}"
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to provision GKE cluster. See error above. Exiting${CLEAR}\n"
    exit 1
fi
printf "${GREEN}Successfully provisioned GKE cluster ${GKE_CLUSTER_NAME}.${CLEAR}\n"


#----EXTRACTING KUBECONFIG----#
printf "${BLUE}Getting Kubeconfig for the cluster named ${GKE_CLUSTER_NAME}.${CLEAR}\n"
printf "${YELLOW}"
gcloud container clusters get-credentials ${GKE_CLUSTER_NAME} --region="${GCLOUD_REGION}"
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to get credentials for GKE cluster ${GKE_CLUSTER_NAME}, complaining and continuing${CLEAR}\n"
    exit 1
fi

# Check for which base64 command we have available so we can use the right option
echo | base64 -w 0 > /dev/null 2>&1
if [ $? -eq 0 ]; then
  # GNU coreutils base64, '-w' supported
  BASE64_OPTION=" -w 0"
else
  # Openssl base64, no wrapping by default
  BASE64_OPTION=" "
fi

kubectl apply -f deploy/cluster-admin-role.yaml &> /dev/null

# Give cluster time to recognize Service Account & generate token
sleep 1

cp $KUBECONFIG $KUBECONFIG.${GKE_CLUSTER_NAME}

export KUBECONFIG_GKE_CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
cat > "$KUBECONFIG.portable" <<EOF
apiVersion: v1
clusters:
- cluster:
    server: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    insecure-skip-tls-verify: true
  name: ${KUBECONFIG_GKE_CLUSTER_NAME}
contexts:
- context:
    cluster: ${KUBECONFIG_GKE_CLUSTER_NAME}
    namespace: default
    user: kube-system-cluster-admin/${KUBECONFIG_GKE_CLUSTER_NAME}
  name: kube-system-cluster-admin/${KUBECONFIG_GKE_CLUSTER_NAME}
current-context: kube-system-cluster-admin/${KUBECONFIG_GKE_CLUSTER_NAME}
kind: Config
preferences: {}
users:
- name: kube-system-cluster-admin/${KUBECONFIG_GKE_CLUSTER_NAME}
  user:
    token: $(kubectl get $(kubectl get secret -n kube-system -o name | grep cluster-admin-token | head -n 1) -n kube-system -o jsonpath={.data.token} | base64 -d ${BASE64_OPTION})
EOF

# # take portable kubeconfig and replace original kubeconfig
cp $KUBECONFIG.portable $KUBECONFIG
rm $KUBECONFIG.portable

printf "${GREEN}You can find your kubeconfig file for this cluster in $KUBECONFIG.\n${CLEAR}"
printf "${CLEAR}"

# the provision_wrapper.sh expects this path to read information
STATE_FILE=${OUTPUT_DEST}/${CLUSTER_NAME}.json

#-----DUMP STATE FILE----#
echo "{
    \"CLUSTER_NAME\": \"${GKE_CLUSTER_NAME}\",
    \"REGION\": \"${GCLOUD_REGION}\",
    \"PLATFORM\": \"GCLOUD\"
}" | tee -a ${STATE_FILE}

printf "${GREEN}GKE cluster provision successful.  Cluster named ${GKE_CLUSTER_NAME} created. \n"
printf "State file saved for cleanup in ${STATE_FILE}${CLEAR}\n"
