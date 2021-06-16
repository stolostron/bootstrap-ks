# Create OpenShift Pull Secret
oc create secret generic -n bootstrap-ks openshift-pull-secret --from-file=pull-secret.txt=$OCP_PULL_SECRET_FILE
# Create a secret for ARO
oc create secret generic bootstrap-ks-aro-creds \
    -n bootstrap-ks \
    --from-literal=AZURE_PASS=$AZURE_PASS \
    --from-literal=AZURE_USER=$AZURE_USER \
    --from-literal=AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID \
    --from-literal=TARGET_KS=aro;
# Create a secret for AKS
oc create secret generic bootstrap-ks-aks-creds \
    -n bootstrap-ks \
    --from-literal=AZURE_PASS=$AZURE_PASS \
    --from-literal=AZURE_USER=$AZURE_USER \
    --from-literal=AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID \
    --from-literal=TARGET_KS=aks;