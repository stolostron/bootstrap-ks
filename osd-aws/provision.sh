#!/bin/bash

# Color codes for bash output
BLUE='\e[36m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CLEAR='\e[39m'

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

# Ensure ADMIN_USER/PASSWORD have values
ADMIN_USER=${ADMIN_USER:-"Cluster-Admin"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"`head /dev/urandom | LC_CTYPE=C tr -dc A-Za-z0-9 | head -c 80 ; echo ''`"}

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

ocm create cluster --ccs --aws-access-key-id $AWS_ACCESS_KEY_ID --aws-account-id $AWS_ACCOUNT_ID --aws-secret-access-key $AWS_SECRET_ACCESS_KEY --compute-nodes $AWS_NODE_COUNT --compute-machine-type $AWS_MACHINE_TYPE --region $AWS_REGION $OSDAWS_CLUSTER_NAME
if [ "$?" -ne 0 ]; then
    printf "${RED}Failed to provision cluster. See error above. Exiting${CLEAR}\n"
    exit 1
fi
printf "${GREEN}Successfully provisioned cluster ${OSDAWS_CLUSTER_NAME}.${CLEAR}\n"

CLUSTER_NAME=$OSDAWS_CLUSTER_NAME

printf "${GREEN}Cluster name: '${CLUSTER_NAME}${CLEAR}'\n"

CLUSTER_ID=`ocm list clusters --parameter search="name like '${CLUSTER_NAME}'" --no-headers | awk  '{ print $1 }'`
printf "${GREEN}Cluster ID: '${CLUSTER_ID}${CLEAR}'\n"

CLUSTER_DOMAIN=`ocm get /api/clusters_mgmt/v1/clusters/$CLUSTER_ID | jq -r '.dns.base_domain'`
printf "${GREEN}Cluster domain: '${CLUSTER_DOMAIN}${CLEAR}'\n"

# Configure IDP and users
# Need to loop over this - to wait until it comes available

while ! ocm create idp --cluster=$CLUSTER_NAME --type htpasswd --name htpasswd --username ${ADMIN_USER} --password ${ADMIN_PASSWORD}
do
    printf "${YELLOW}Waiting for cluster to become active...${CLEAR}\n"
    sleep 30
done

printf "${GREEN}Adding user ${ADMIN_USER} as admin.${CLEAR}\n"

ocm create user ${ADMIN_USER} --cluster=$CLUSTER_ID --group=cluster-admins
ocm create user ${ADMIN_USER} --cluster=$CLUSTER_ID --group=dedicated-admins

#-----DUMP STATE FILE----#
LOGIN_URL=https://console-openshift-console.apps.$OSDAWS_CLUSTER_NAME.$CLUSTER_DOMAIN
STATE_FILE=$(pwd)/${OSDAWS_CLUSTER_NAME}.json
cat > $(pwd)/${OSDAWS_CLUSTER_NAME}.json <<EOF
{
    "CLUSTER_NAME": "${OSDAWS_CLUSTER_NAME}",
    "CLUSTER_ID": "${CLUSTER_ID}",
    "REGION": "${AWS_REGION}",
    "USERNAME": "${ADMIN_USER}",
    "PASSWORD": "${ADMIN_PASSWORD}",
    "LOGIN_URL": "${LOGIN_URL}",
    "OCM_URL": "${OCM_URL}",
    "PLATFORM": "OSD-AWS"
}
EOF

printf "${GREEN}Cluster provision successful.  Cluster named ${OSDAWS_CLUSTER_NAME} created. \n"
printf "${GREEN}Console URL: ${LOGIN_URL}\n${CLEAR}"
printf "${GREEN}Username: ${ADMIN_USER}\n${CLEAR}"
printf "${GREEN}Password: *****\n${CLEAR}"
printf "${GREEN}Full Password and username can be found in ${STATE_FILE}\n${CLEAR}"
printf "${GREEN}To destroy this cluster run './destroy.sh ${STATE_FILE}'\n${CLEAR}"
