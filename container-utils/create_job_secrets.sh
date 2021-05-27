oc create secret generic -n bootstrap-ks openshift-pull-secret --from-file=pull-secret.txt=$OCP_PULL_SECRET_FILE
oc create secret generic bootstrap-ks-provision-config \
    -n bootstrap-ks \
    --from-literal=azure_pass=$AZURE_PASS \
    --from-literal=azure_user=$AZURE_USER \
    --from-literal=azure_base_domain_resource_group_name=$AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME \
    --from-literal=azure_base_domain=$AZURE_BASE_DOMAIN \
    --from-literal=cluster_name=$CLUSTER_NAME \
    --from-literal=azure_subscription_id=$AZURE_SUBSCRIPTION_ID;