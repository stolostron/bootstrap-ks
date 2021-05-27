# Containerized other-ks Provisioning

**NOTE: currently only aro is supported as a platform**

## Building the Image

In order to build this repository as a docker image, nagivate to the root directory of this repository (`cd ../`) and run `docker build .`, then tag and push as desired.  

## Provisioning a Cluster as a Kubernetes Job

## Prereqs

Before you can provision a cluster via a kuberentes job, you need to do some setup on your cluster.  

**NOTE**: this is very early documentation and this process _will_ be refined.  

1. `oc login` to the cluster you'll run the kubernetes job on.
2. Create a namespace called `bootstrap-ks` on your cluster - this is where the jobs will operate.  You can use any namespace you desire, but if you do, you'll need to change all namespace references in `prereqs.yaml`, `create_job_secrets.sh`, and `bootstrap-ks.job.yaml`.  
3. Set the folowing environment variables:
```
OCP_PULL_SECRET_FILE - the path to your ocp pull_secret.txt file acquired from cloud.redhat.com
AZURE_PASS - your Azure console password - this requirement will eventually be optionally substituted with service principle details
AZURE_USER - yoru Azure console username - this requirement will eventually be optionally substituted with service principle details
AZURE_BASE_DOMAIN_RESOURCE_GROUP_NAME - the name of the resource group that holds the base domain you wish to use for you cluster
AZURE_BASE_DOMAIN - the base domain to use for your cluster
CLUSTER_NAME - the desired cluster name - this will also be the name of secrets created by the job on your cluster
AZURE_SUBSCRIPTION_ID - the azure subscription id you wish to use
```
4. Run `./create_job_secrets.sh` to create two secrets holding the above env vars that will be mounted and used in the provision.  
5. `oc apply -f prereqs.yaml` to create a service account with permissions to create secrets.  This will be used by the provision job to create a secret on your cluster representing the provisioned ks cluster.  
6. *If you built a custom bootstrap-ks image* update `bootstrap-ks.job.yaml` to point at that image.
7. Run `oc apply -f bootstrap-ks.job.yaml` to create the provision job.  