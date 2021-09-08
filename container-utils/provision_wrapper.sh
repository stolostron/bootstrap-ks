#!/bin/bash

# provision_wrapper.sh
#   This file wraps a call to the provision.sh in the target other-ks platform
#       specifically for bootstrap-ks in a containerized form.
#   This is the entrypoint for containerized bootstrap-ks.
#   This script also handles the creation of a kubernetes secret containing data
#       on the provisioned cluster.
#

OPERATION=$(echo $OPERATION | tr '[:lower:]' '[:upper:]')

if [[ "$OPERATION" == "DESTROY" ]]; then
    if [[ "$TARGET_KS" == "aro" ]]; then
        echo "#### Destroying ${CLUSTER_NAME} on ARO"
        pushd aro
        mkdir ${OUTPUT_DEST}/${CLUSTER_NAME}
        oc extract secret/${CLUSTER_NAME} --keys=json --to=${OUTPUT_DEST}/${CLUSTER_NAME}
        ./destroy.sh ${OUTPUT_DEST}/${CLUSTER_NAME}/json
        popd
    elif [[ "$TARGET_KS" == "aks" ]]; then
        echo "#### Destroying ${CLUSTER_NAME} on AKS"
        pushd aks
        mkdir ${OUTPUT_DEST}/${CLUSTER_NAME}
        oc extract secret/${CLUSTER_NAME} --keys=json --to=${OUTPUT_DEST}/${CLUSTER_NAME}
        ./destroy.sh ${OUTPUT_DEST}/${CLUSTER_NAME}/json
        popd
    elif [[ "$TARGET_KS" == "rosa" ]]; then
        echo "#### Destroying ${CLUSTER_NAME} on ROSA"
        pushd rosa
        mkdir ${OUTPUT_DEST}/${CLUSTER_NAME}
        oc extract secret/${CLUSTER_NAME} --keys=json --to=${OUTPUT_DEST}/${CLUSTER_NAME}
        ./destroy.sh ${OUTPUT_DEST}/${CLUSTER_NAME}/json
        popd
    elif [[ "$TARGET_KS" == "eks" ]]; then
        echo "#### Destroying ${CLUSTER_NAME} on EKS"
        pushd eks
    elif [[ "$TARGET_KS" == "gke" ]]; then
        echo "#### Destroying ${CLUSTER_NAME} on GKE"
        pushd gke
        mkdir ${OUTPUT_DEST}/${CLUSTER_NAME}
        oc extract secret/${CLUSTER_NAME} --keys=json --to=${OUTPUT_DEST}/${CLUSTER_NAME}
        ./destroy.sh ${OUTPUT_DEST}/${CLUSTER_NAME}/json
        popd
    else
        echo "Platform ${TARGET} currently unsupported via image/kubernetes job.  Exiting"
        exit 0
    fi
elif [[ "$OPERATION" == "CREATE" ]]; then
    if [[ "$TARGET_KS" == "aro" ]]; then
        echo "#### Provisioning ${CLUSTER_NAME} on ARO"
        STATE_FILE=${OUTPUT_DEST}/${CLUSTER_NAME}.json
        pushd aro
        ./provision.sh \
            && oc create secret generic ${CLUSTER_NAME} \
                --from-file=json=${STATE_FILE} \
                --from-literal=resource_group_name=`cat ${STATE_FILE} | jq -r '.RESOURCE_GROUP_NAME'` \
                --from-literal=cluster_name=`cat ${STATE_FILE} | jq -r '.CLUSTER_NAME'` \
                --from-literal=region=`cat ${STATE_FILE} | jq -r '.REGION'` \
                --from-literal=azure_subscription_id=`cat ${STATE_FILE} | jq -r '.SUBSCRIPTION'` \
                --from-literal=cloud_platform=`cat ${STATE_FILE} | jq -r '.PLATFORM'` \
                --from-literal=azure_base_domain_resource_group_name=`cat ${STATE_FILE} | jq -r '.AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME'` \
                --from-literal=basedomain=`cat ${STATE_FILE} | jq -r '.CLUSTER_NAME'`.`cat ${STATE_FILE} | jq -r '.AZURE_BASE_DOMAIN'` \
                --from-literal=username=`cat ${STATE_FILE} | jq -r '.USERNAME'` \
                --from-literal=password=`cat ${STATE_FILE} | jq -r '.PASSWORD'` \
                --from-literal=console_url=`cat ${STATE_FILE} | jq -r '.CONSOLE_URL'` \
                --from-literal=identity_provider=`cat ${STATE_FILE} | jq -r '.IDENTITY_PROVIDER'` \
                --from-literal=api_url=`cat ${STATE_FILE} | jq -r '.API_URL'`;
        popd
    elif [[ "$TARGET_KS" == "aks" ]]; then
        echo "#### Provisioning ${CLUSTER_NAME} on AKS"
        STATE_FILE=${OUTPUT_DEST}/${CLUSTER_NAME}.json
        KUBECONFIG_FILE=${OUTPUT_DEST}/${CLUSTER_NAME}.kubeconfig
        pushd aks
        ./provision.sh \
            && oc create secret generic ${CLUSTER_NAME} \
                --from-file=json=${STATE_FILE} \
                --from-file=kubeconfig=${KUBECONFIG_FILE} \
                --from-literal=resource_group_name=`cat ${STATE_FILE} | jq -r '.RESOURCE_GROUP_NAME'` \
                --from-literal=cluster_name=`cat ${STATE_FILE} | jq -r '.CLUSTER_NAME'` \
                --from-literal=resource_name=`cat ${STATE_FILE} | jq -r '.RESOURCE_NAME'` \
                --from-literal=region=`cat ${STATE_FILE} | jq -r '.REGION'` \
                --from-literal=azure_subscription_id=`cat ${STATE_FILE} | jq -r '.SUBSCRIPTION'` \
                --from-literal=cloud_platform=`cat ${STATE_FILE} | jq -r '.PLATFORM'`;
        popd
    elif [[ "$TARGET_KS" == "rosa" ]]; then
        echo "#### Provisioning ${CLUSTER_NAME} on ROSA"
        STATE_FILE=${OUTPUT_DEST}/${CLUSTER_NAME}.json
        pushd rosa
        ./provision.sh \
            && oc create secret generic ${CLUSTER_NAME} \
                --from-file=json=${STATE_FILE} \
                --from-literal=cluster_name=`cat ${STATE_FILE} | jq -r '.CLUSTER_NAME'` \
                --from-literal=region=`cat ${STATE_FILE} | jq -r '.REGION'` \
                --from-literal=cloud_platform=`cat ${STATE_FILE} | jq -r '.PLATFORM'` \
                --from-literal=aws_account_id=`cat ${STATE_FILE} | jq -r '.AWS_ACCOUNT_ID'` \
                --from-literal=username=`cat ${STATE_FILE} | jq -r '.USERNAME'` \
                --from-literal=password=`cat ${STATE_FILE} | jq -r '.PASSWORD'` \
                --from-literal=console_url=`cat ${STATE_FILE} | jq -r '.CONSOLE_URL'` \
                --from-literal=identity_provider=`cat ${STATE_FILE} | jq -r '.IDENTITY_PROVIDER'` \
                --from-literal=api_url=`cat ${STATE_FILE} | jq -r '.API_URL'`;
        popd
    elif [[ "$TARGET_KS" == "eks" ]]; then
        echo "#### Provisioning ${CLUSTER_NAME} on EKS"
        STATE_FILE=${OUTPUT_DEST}/${CLUSTER_NAME}.json
        KUBECONFIG_FILE=${OUTPUT_DEST}/${CLUSTER_NAME}.kubeconfig
        pushd eks
    elif [[ "$TARGET_KS" == "gke" ]]; then
        echo "#### Provisioning ${CLUSTER_NAME} on GKE"
        STATE_FILE=${OUTPUT_DEST}/${CLUSTER_NAME}.json
        KUBECONFIG_FILE=${OUTPUT_DEST}/${CLUSTER_NAME}.kubeconfig
        pushd gke
        ./provision.sh \
            && oc create secret generic ${CLUSTER_NAME} \
                --from-file=json=${STATE_FILE} \
                --from-file=kubeconfig=${KUBECONFIG_FILE} \
                --from-literal=cluster_name=`cat ${STATE_FILE} | jq -r '.CLUSTER_NAME'` \
                --from-literal=region=`cat ${STATE_FILE} | jq -r '.REGION'` \
                --from-literal=cloud_platform=`cat ${STATE_FILE} | jq -r '.PLATFORM'`;
        #cm attach cluster --cluster ${CLUSTER_NAME} --cluster-kubeconfig ${KUBECONFIG_FILE}
        popd
        # Requires ${CLUSTER_NAME} and ${KUBECONFIG_FILE} to be defined
        pushd import-cluster
        ./import.sh
        popd
    else
        echo "Platform ${TARGET} currently unsupported via image/kubernetes job.  Exiting"
        exit 0
    fi
else
    echo "Operation '${OPERATION}' not supported, only supported operations are 'CREATE' or 'DESTROY'."
    exit 1
fi