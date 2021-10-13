## Azure Kubernetes Service (AKS)

This module can be used to install dependencies for Azure Kubernetes Service (AKS) provisioning (the `az` cli), provision an AKS cluster, and destroy an aks cluster provisioned using this utility.  

### Getting Started
*Optionally* run install.sh, this only works on MacOS and Fedora-based Linux instances.  

### Provisioning
1. Set the following env vars before provisioning:

```bash
# The module use username/password as the default login method, and set below env vars for login.
export AZURE_USER=<your-azure-username>
export AZURE_PASS=<your-azure-password>

# And the module also support use service principal method, set below env vars for login.
export SERVICE_PRINCIPAL=true
export CLIENT_ID=<your-azure-clientID>
export CLIENT_SECRET=<your-azure-client-secret>
export TENANT_ID=<your-azure-tenantID>

# Optional
export CLUSTER_NAME=<some cluster name> 
# if you set a cluster name, we will use it as a base name for all resources created and append a unique identifier
# if CLUSTER_NAME is not specified, we will use the first 8 characters of the system's username

export AZURE_REGION=<region>  # defaults to eastus
```

2. run `./provision.sh`
3. if successful, you will see a `.json` and `.kubeconfig` file with metadata for your cluster!

### Cleaning up a cluster
1. run `./destroy.sh <.json file of your cluster metadata>`
