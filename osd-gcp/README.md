## OpenShift Dedicated on GCP (OSD-GCP)

This module can be used to install dependencies for OpenShift Dedicated on GCP (OSD-GCP) provisioning (the `ocm` cli), provision an OSD cluster, and destroy an OSD cluster provisioned using this utility.

### Getting Started
*Optionally* run install.sh, this only works on MacOS and Fedora-based Linux instances.  

### Provisioning
1. Set the following env vars before provisioning in GCP:

```
export GCLOUD_CREDS_FILE=<path to your osd-ccs-admin service account json>
export OCM_TOKEN=<Red Hat OCM token>

# Optional
export GCLOUD_REGION=<Google Cloud region, defaults to "us-east1">
export GCLOUD_NODE_COUNT=<Node count, defaults to "3">
export OCM_URL=<one of: 'production', 'staging', 'integration'>

export CLUSTER_NAME=<some cluster name> # if you set a cluster name, we will use it as a base name for all resources created and append a unique identifier
# if CLUSTER_NAME is not specified, we will use the first 8 characters of the system's username
# note that cluster names are a maximum of 15 characters, and we append three - so you effectively get 12
```

2. run `./provision.sh`
3. if successful, you will see a `.json` file with metadata for your cluster!
4. You will then need to run the following commands interactively:

```
ocm create idp --cluster=<cluster_id>  <-- choose github, follow the prompts, give your app permission in github
ocm create user <github user> --cluster=<cluster_id> --group=cluster-admins
ocm create user <github user> --cluster=<cluster_id> --group=dedicated-admins
Log in to your cluster, get the login token
oc login
```
...and now you have a kubeconifg with your credentials.

### Cleaning up a cluster
1. run `./destroy.sh <.json file of your cluster metadata>`
