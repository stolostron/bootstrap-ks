## IKS

This module can be used to install dependencies for IKS provisioning (the `ibmcloud` cli), provision an IKS/ROKS cluster, and destroy an IKS/ROKS cluster provisioned using this utility.  

### Getting Started
*Optionally* run install.sh, this only works on MacOS and Fedora-based Linux instances.  

### Provisioning
1. Set the following env vars before provisioning:

```
export IBMCLOUD_APIKEY=<your-ibmcloud-apikey>

# Optional
export CLUSTER_NAME=<some cluster name> # if you set a cluster name, we will use it as a base name for all resources created and append a unique identifier
# if CLUSTER_NAME is not specified, we will use the first 8 characters of the system's username

export FLAVOR=<type of instance to use from 'ibmcloud ks flavors --zone [some-zone]'>
export IBMCLOUD_REGION=<region to deploy to, default us-east>
export IBMCLOUD_ZONE=<zone to deploy into, default dal10>
export IKS_WORKER_COUNT=<number of workers to provision, default 3>
export ROKS=<true for ROKS default version or false for iks default version, default false>
export KUBERNETES_VERSION_OVERRIDE=<override for kubernetes version, set to a value from 'ibmcloud ks versions'>
```

2. run `./provision.sh`
3. if successful, you will see a `.json` and `.kubeconfig` file with metadata for your cluster!

### Cleaning up a cluster
1. run `./destroy.sh <.json file of your cluster metadata>`