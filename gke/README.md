## Google Kubernetes Engine (GKE)

This module can be used to install dependencies for Google Kubernetes Engine (GKE) provisioning (the `gcloud` cli), provision a GKE cluster, and destroy an GKE cluster provisioned using this utility.

### Getting Started
*Optionally* run install.sh, this only works on MacOS and Fedora-based Linux instances.

### Provisioning
1. Set the following env vars before provisioning:

```
export GCLOUD_CREDS_FILE=<your-gcloud-json-key-file, usually ~/.gcp/osServiceAccount.json> (this will default to ~/.gcp/osServiceAccount.json so its not technically required)
export GCLOUD_PROJECT_ID=<your-gcloud-project-id>

# Optional
export CLUSTER_NAME=<some cluster name> # if you set a cluster name, we will use it as a base name for all resources created and append a unique identifier
# if CLUSTER_NAME is not specified, we will use the first 8 characters of the system's username

export GCLOUD_NODE_COUNT=<desired node count>
export GCLOUD_REGION=<desired region>         # defaults to us-east1
```

2. run `./provision.sh`
3. if successful, you will see a `.json` and `.kubeconfig` file with metadata for your cluster!

### Cleaning up a cluster
1. run `./destroy.sh <.json file of your cluster metadata>`

## Provisioning through a Kubernetes Job

Create the following configuration files with your desired settings:

## bootstrap-ks-config.secret

```bash
CLUSTER_NAME=gke-cluster
GCLOUD_REGION=us-east4-a
GCLOUD_NODE_COUNT=2
OPERATION=CREATE
TARGET_KS=gke
```

## bootstrap-ks-creds.secret
```bash
GCLOUD_PROJECT_ID=
```

## gcp-credentials.json

Download your GCP Service Account JSON file.

## Apply kustomization.yaml

Opetionally, edit the `namePrefix` within `gke/deploy/kustomization.yaml.

```bash
oc apply -f gke/deploy/prereqs.yaml
oc create -k gke/deploy
```


