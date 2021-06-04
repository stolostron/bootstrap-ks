## OpenShift Dedicated (OSD)

This module can be used to install dependencies for OpenShift Dedicated (OSD) provisioning (the `ocm` cli), provision an OSD cluster, and destroy an OSD cluster provisioned using this utility.
OSD clusters can be backed by Google Cloud or Amazon AWS services.

### Getting Started
*Optionally* run install.sh, this only works on MacOS and Fedora-based Linux instances.  

### Provisioning
1. Set the following env vars before provisioning in AWS:

```
export AWS_ACCOUNT_ID=<your AWS account ID>
export AWS_ACCESS_KEY_ID=<your AWS access key ID>
export AWS_SECRET_ACCESS_KEY=<your AWS secret access key>
export AWS_REGION=<region>  # defaults to us-east-1
exoprt AWS_NODE_COUNT=<number> $ defaults to 3

# Optional
export CLUSTER_NAME=<some cluster name> # if you set a cluster name, we will use it as a base name for all resources created and append a unique identifier
# if CLUSTER_NAME is not specified, we will use the first 8 characters of the system's username
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
