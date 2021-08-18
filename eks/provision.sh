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
NAME_SUFFIX="eks"

# Default to us-east-1
EKS_REGION=${EKS_REGION:-"us-east-1"}
EKS_NODE_COUNT=${EKS_NODE_COUNT:-"3"}

# Optional - defaults is to auto-select
EKS_ZONES=${EKS_ZONES:-""}

# Writable directory to hold results and temporary files for containerized application - default to the current directory
OUTPUT_DEST=${OUTPUT_DEST:-PWD}


#----VALIDATE ENV VARS----#
# Validate that we have all required env vars and exit with a failure if any are missing
missing=0

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
STATE_FILE=${OUTPUT_DEST}/${RESOURCE_NAME}.json


#----VERIFY Amazon EKS CLI----#
if [ -z "$(which eksctl)" ]; then
    printf "${RED}Could not find the eksctl cli, exiting.  Try running ./install.sh.${CLEAR}\n"
    exit 1
fi


#----CREATE EKS CLUSTER----#
EKS_CLUSTER_NAME="${RESOURCE_NAME}"
printf "${BLUE}Creating an EKS cluster named ${EKS_CLUSTER_NAME}.${CLEAR}\n"
printf "${YELLOW}"

OPTIONAL_PARAMS=""
if [ ! -z "$EKS_ZONES" ]; then
  OPTIONAL_PARAMS=$"${OPTIONAL_PARAMS} --zones ${EKS_ZONES} "
fi

eksctl create cluster \
  --name "${EKS_CLUSTER_NAME}" \
  --nodes "${EKS_NODE_COUNT}" \
  --region "${EKS_REGION}" \
  --kubeconfig "${OUTPUT_DEST}/${EKS_CLUSTER_NAME}.kubeconfig" ${OPTIONAL_PARAMS}

if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to provision EKS cluster. See error above. Exiting${CLEAR}\n"
    exit 1
fi

printf "${GREEN}Successfully provisioned EKS cluster ${EKS_CLUSTER_NAME}.${CLEAR}\n"


#----Make KUBECONFIG that is useable from anywhere ----#
export KUBECONFIG_SAVED=$KUBECONFIG
export KUBECONFIG=${OUTPUT_DEST}/${EKS_CLUSTER_NAME}.kubeconfig

# Check for which base64 command we have available so we can use the right option
echo | base64 -w 0 > /dev/null 2>&1
if [ $? -eq 0 ]; then
  # GNU coreutils base64, '-w' supported
  BASE64_OPTION=" -w 0"
else
  # Openssl base64, no wrapping by default
  BASE64_OPTION=" "
fi

echo | kubectl apply -f - &> /dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-admin
  namespace: kube-system
EOF

echo | kubectl apply -f - &> /dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-system-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: cluster-admin
  namespace: kube-system
EOF

sleep 1

cat > "${OUTPUT_DEST}/${EKS_CLUSTER_NAME}.kubeconfig.portable" <<EOF
apiVersion: v1
clusters:
- cluster:
    server: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    insecure-skip-tls-verify: true
  name: $(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
contexts:
- context:
    cluster: $(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
    namespace: default
    user: kube-system-cluster-admin/$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
  name: kube-system-cluster-admin/$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
current-context: kube-system-cluster-admin/$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
kind: Config
preferences: {}
users:
- name: kube-system-cluster-admin/$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
  user:
    token: $(kubectl get $(kubectl get secret -n kube-system -o name | grep cluster-admin-token | head -n 1) -n kube-system -o jsonpath={.data.token} | base64 -d ${BASE64_OPTION})
EOF

# take portable kubeconfig and replace original kubeconfig
cp ${OUTPUT_DEST}/${EKS_CLUSTER_NAME}.kubeconfig.portable ${OUTPUT_DEST}/${EKS_CLUSTER_NAME}.kubeconfig
rm ${OUTPUT_DEST}/${EKS_CLUSTER_NAME}.kubeconfig.portable

# Set KUBECONFIG to what it used to be
export KUBECONFIG=$KUBECONFIG_SAVED


#-----DUMP STATE FILE----#
cat > ${OUTPUT_DEST}/${EKS_CLUSTER_NAME}.json <<EOF
{
    "CLUSTER_NAME": "${EKS_CLUSTER_NAME}",
    "REGION": "${EKS_REGION}",
    "PLATFORM": "EKS"
}
EOF


#----EXTRACTING KUBECONFIG----#
printf "${GREEN}You can find your kubeconfig file for this cluster in ${OUTPUT_DEST}/${EKS_CLUSTER_NAME}.kubeconfig\n${CLEAR}"
printf "${CLEAR}"


printf "${GREEN}EKS cluster provision successful.  Cluster named ${EKS_CLUSTER_NAME} created. \n"
printf "State file saved for cleanup in ${OUTPUT_DEST}/${EKS_CLUSTER_NAME}.json${CLEAR}\n"
