#!/bin/sh

# Assumes ${CLUSTER_NAME} is defined

oc create namespace ${CLUSTER_NAME}

# Give the namespace time to populate
sleep 5

echo "Creating auto-import-secret for ${CLUSTER_NAME}..."
echo | kubectl apply -f - <<EOF
kind: Secret
apiVersion: v1
metadata:
  name: auto-import-secret
  namespace: ${CLUSTER_NAME}
stringData:
  autoImportRetry: "2"
  kubeconfig: |
$(cat ${KUBECONFIG_FILE} | sed 's/^/    /')
type: Opaque
EOF

# Let the kube-apiserver have enough time to recognize the secret
sleep 2

echo "Creating ManagedCluster for ${CLUSTER_NAME}..."
echo | kubectl apply -f - <<EOF
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: ${CLUSTER_NAME}
  labels:
    cluster.open-cluster-management.io/clusterset: all-clusters
spec:
  hubAcceptsClient: true
  leaseDurationSeconds: 60
EOF

echo "Creating KlusterletAddonConfig for ${CLUSTER_NAME}..."
echo | kubectl apply -f - <<EOF
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  labels:
    installer.name: multiclusterhub
    installer.namespace: open-cluster-management
  name: ${CLUSTER_NAME}
  namespace: ${CLUSTER_NAME}
spec:
  applicationManager:
    argocdCluster: false
    enabled: true
  certPolicyController:
    enabled: true
  clusterLabels:
    cloud: auto-detect
    vendor: auto-detect
  clusterName: ${CLUSTER_NAME}
  clusterNamespace: ${CLUSTER_NAME}
  iamPolicyController:
    enabled: true
  policyController:
    enabled: true
  searchCollector:
    enabled: false
  version: 2.4.0
EOF