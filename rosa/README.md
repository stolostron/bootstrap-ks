## Red Hat OpenShift Service on AWS (ROSA)

This module can be used to install dependencies for Red Hat OpenShift Service on AWS (ROSA) provisioning (the `aws` and `rosa` cli tools), provision a ROSA cluster, and destroy a ROSA cluster provisioned using this utility.  

### Getting Started
*Optionally* run install.sh, this only works on MacOS and Fedora-based Linux instances.  

### Provisioning
1. Set the following env vars before provisioning:

```
WIP
```

2. run `./provision.sh`
3. if successful, you will see a `.json` and `.cred.json` file with metadata for your cluster!

### Cleaning up a cluster
1. run `./destroy.sh <.json file of your cluster metadata>`
