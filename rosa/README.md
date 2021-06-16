## Red Hat OpenShift Service on AWS (ROSA)

This module can be used to install dependencies for Red Hat OpenShift Service on AWS (ROSA) provisioning (the `aws` and `rosa` cli tools), provision a ROSA cluster, and destroy a ROSA cluster provisioned using this utility.  

### Getting Started
*Optionally* run install.sh, this only works on MacOS and Linux.  

### Provisioning
1. Set the following env vars before provisioning:

```
export ROSA_TOKEN=<your-rosa-token> # Find this token at https://cloud.redhat.com/openshift/token/rosa
export AWS_ACCESS_KEY_ID=<your-access-key-id-from-aws>
export AWS_SECRET_ACCESS_KEY=<your-secret-access-key-from-aws>

# Optional
export CLUSTER_NAME=<some cluster name> # if you set a cluster name, we will use it as a base name for all resources created and append a unique identifier
# if CLUSTER_NAME is not specified, we will use the first 8 characters of the system's username

export AWS_REGION=<region>  # defaults to us-east-1
export OCP_VERSION=<version> # defaults to ROSA default version
export AWS_WORKER_TYPE=<instance-type> # defaults to m5.xlarge
export AWS_WORKER_COUNT=<number-of-workers> # defaults to 3
export CHANNEL_GROUP=<ocp-release-channel> # defaults to "stable"
```

2. run `./provision.sh`
3. if successful, you will see a `.json` file with metadata for your cluster!

### Cleaning up a cluster
1. run `./destroy.sh <.json file of your cluster metadata>`
