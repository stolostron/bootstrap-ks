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

# Help for MacOS
export LC_ALL=C

#----DEFAULTS----#
# Generate a 5-digit random cluster identifier for resource tagging purposes
RANDOM_IDENTIFIER=$(head /dev/urandom | LC_CTYPE=C tr -dc a-z0-9 | head -c 2 ; echo '')
# Ensure USER has a value
if [ -z "$JENKINS_HOME" ]; then
  USER=${USER:-"unknown"}
else
  USER=${USER:-"jenkins"}
fi


SHORTNAME=$(echo $USER | head -c 7)

# Generate a default resource name
RESOURCE_NAME="$SHORTNAME-$RANDOM_IDENTIFIER"
NAME_SUFFIX="odaw"

# Default to us-east-1
AWS_REGION=${AWS_REGION:-"us-east-1"}
AWS_NODE_COUNT=${AWS_NODE_COUNT:-"3"}
AWS_MACHINE_TYPE=${AWS_MACHINE_TYPE:-"m5.xlarge"}
# OCM_URL can be one of: 'production', 'staging', 'integration'
OCM_URL=${OCM_URL:-"staging"}

#----VALIDATE ENV VARS----#
# Validate that we have all required env vars and exit with a failure if any are missing
missing=0

if [ -z "$AWS_ACCOUNT_ID" ]; then
    printf "${RED}AWS_ACCOUNT_ID env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    printf "${RED}AWS_ACCESS_KEY_ID env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi
if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    printf "${RED}AWS_SECRET_ACCESS_KEY env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi
if [ -z "$OCM_TOKEN" ]; then
    printf "${RED}OCM_TOKEN env var not set. flagging for exit.${CLEAR}\n"
    missing=1
fi

if [ "$missing" -ne 0 ]; then
    exit $missing
fi

if [ ! -z "$CLUSTER_NAME" ]; then
    RESOURCE_NAME="$CLUSTER_NAME-$RANDOM_IDENTIFIER"
fi
printf "${BLUE}Using $RESOURCE_NAME to identify all created resources.${CLEAR}\n"


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

#----CREATE CLUSTER----#
OSDAWS_CLUSTER_NAME="${RESOURCE_NAME}-${NAME_SUFFIX}"
printf "${BLUE}Creating an OSD cluster on AWS named ${OSDAWS_CLUSTER_NAME}.${CLEAR}\n"
printf "${YELLOW}"

OPTIONAL_PARAMS=""

ocm create cluster --ccs --aws-access-key-id $AWS_ACCESS_KEY_ID --aws-account-id $AWS_ACCOUNT_ID --aws-secret-access-key $AWS_SECRET_ACCESS_KEY --compute-nodes $AWS_NODE_COUNT --compute-machine-type $AWS_MACHINE_TYPE --region $AWS_REGION $OSDAWS_CLUSTER_NAME
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to provision cluster. See error above. Exiting${CLEAR}\n"
    exit 1
fi
printf "${GREEN}Successfully provisioned cluster ${OSDAWS_CLUSTER_NAME}.${CLEAR}\n"

CLUSTER_ID=`ocm list clusters --parameter search="name like '${OSDAWS_CLUSTER_NAME}'" --no-headers | awk  '{ print $1 }'`

#----Make KUBECONFIG that is useable from anywhere ----#
export KUBECONFIG_SAVED=$KUBECONFIG
export KUBECONFIG=$(pwd)/${OSDAWS_CLUSTER_NAME}.kubeconfig

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

cat > "$(pwd)/${OSDAWS_CLUSTER_NAME}.kubeconfig.portable" <<EOF
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
cp $(pwd)/${OSDAWS_CLUSTER_NAME}.kubeconfig.portable $(pwd)/${OSDAWS_CLUSTER_NAME}.kubeconfig
rm $(pwd)/${OSDAWS_CLUSTER_NAME}.kubeconfig.portable

# Set KUBECONFIG to what it used to be
export KUBECONFIG=$KUBECONFIG_SAVED



#-----DUMP STATE FILE----#
cat > $(pwd)/${OSDAWS_CLUSTER_NAME}.json <<EOF
{
    "CLUSTER_NAME": "${OSDAWS_CLUSTER_NAME}",
    "CLUSTER_ID": "${CLUSTER_ID}",
    "REGION": "${AWS_REGION}",
    "URL": "${OCM_URL}",
    "PLATFORM": "OSD-AWS"
}
EOF


#----EXTRACTING KUBECONFIG----#
printf "${GREEN}You can find your kubeconfig file for this cluster in $(pwd)/${OSDAWS_CLUSTER_NAME}.kubeconfig\n${CLEAR}"
printf "${CLEAR}"



printf "${GREEN}Cluster provision successful.  Cluster named ${OSDAWS_CLUSTER_NAME} created. \n"
printf "State file saved for cleanup in $(pwd)/${OSDAWS_CLUSTER_NAME}.json${CLEAR}\n"
