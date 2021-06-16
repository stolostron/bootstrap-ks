# Containerized other-ks Provisioning

**NOTE: currently only aro is supported as a platform**

## Building the Image

In order to build this repository as a docker image, nagivate to the root directory of this repository (`cd ../`) and run `docker build .`, then tag and push as desired.  

**NOTE:** The image now uses a [cloudclisbase image that I've built](https://github.com/gurnben/cloud-clis-base-image) which is hosted on quay.io.  It is public - but I've linked to the repo that generated that image, so you can change out the base image for your own built version as desired.

## Provisioning a Cluster as a Kubernetes Job

Before you can provision a cluster via a kuberentes job, you need to do some setup on your cluster.  

**NOTE**: this is very early documentation and this process _will_ be refined.  

1. `oc login` to the cluster you'll run the kubernetes job on.
2. Create a namespace called `bootstrap-ks` on your cluster - this is where the jobs will operate.  You can use any namespace you desire, but if you do, you'll need to change all namespace references in `prereqs.yaml`, `create_job_secrets.sh`, and `kustomization.yaml`.  
3. Set the folowing environment variables:
```
OCP_PULL_SECRET_FILE - the path to your ocp pull_secret.txt file acquired from cloud.redhat.com
AZURE_PASS - your Azure console password - this requirement will eventually be optionally substituted with service principle details
AZURE_USER - yoru Azure console username - this requirement will eventually be optionally substituted with service principle details
AZURE_SUBSCRIPTION_ID - the azure subscription id you wish to use
```
4. Run `./create_job_secrets.sh` to create two secrets holding the above env vars that will be mounted and used in the provision.  
5. `cp bootstrap-ks.config.secret.example bootstrap-ks.config.secret` and edit `bootstrap-ks.config.secret` to customize your cluster provision as desired.  **NOTE:** Be sure to set `OPERATION=CREATE` to provision.  
6. `cp bootstrap-ks.job.yaml.example bootstrap-ks.job.yaml` and edit `bootstrap-ks.job.yaml`'s name and credentials secrets as desired.  Note - the credentials secret must be changed when provisioning different platforms, config secrets should be changed each time you provision or deprovision a different cluster.
8. *If you built a custom bootstrap-ks image* update `kustomization.yaml` to point at that image.
9. Run `oc apply -k .` form within `/container-utils` to create the prereqs and provision job.  


## Deprovisioning a Cluster as a Kubernetes Job

The process for deprovisioning a cluster provisoined as a Kubernetes job is almost idential to provisoning!  Simply repeat the process but set `OPERATION=DESTROY` in `bootstrap-ks.config.secret` and ensure that the secret provided has access to the provisioned cluster and the `CLUSTER_NAME` is the same.  Also of note - you need to edit the job name in `bootstrap-ks.job.yaml` so it doesn't collide with your original provision job.  