## EKS

This module can be used to install dependencies for Amazon Elastic Kubernetes Service (EKS) provisioning (the `gcloud` cli), provision a EKS cluster, and destroy an EKS cluster provisioned using this utility.  

### Getting Started
*Optionally* run install.sh, this only works on MacOS and Fedora-based Linux instances.  

### Provisioning
1. Set the following env vars before provisioning:

```
# Optional
export CLUSTER_NAME=<some cluster name> # if you set a cluster name, we will use it as a base name for all resources created and append a unique identifier
# if CLUSTER_NAME is not specified, we will use the first 8 characters of the system's username

export EKS_REGION=<desired region. Default is us-east-1 >
export EKS_NODE_COUNT=<desired node cound.  Default is 3 >

```

2. run `./provision.sh`
3. if successful, you will see a `.json` and `.kubeconfig` file with metadata for your cluster!

### Cleaning up a cluster
1. run `./destroy.sh <.json file of your cluster metadata>`