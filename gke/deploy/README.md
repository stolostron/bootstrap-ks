

## bootstrap-ks.config.secret

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

## pull-secret.txt

Download from cloud.redhat.com.

## gcp-credentials.json

Download your GCP Service Account JSON file.


## Apply kustomization.yaml

```bash
oc create -k gke/deploy
```

