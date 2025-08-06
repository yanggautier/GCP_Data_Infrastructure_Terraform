# GCP Data pipeline with DBT

## TODO 
- Name of resource with environment
- Tag of environment


## Description
Manage and configuration data infrastructure by using Terraform, this infrastructure includes GCS for Datalake, BigQuery for DataWarehouse, GKE for deploy DBT instance in Kubernetes Clusters.

## Installation
1. Create a Google Cloud project
```bash
 gcloud projects create PROJECT_ID 
```
2.  Select the Google Cloud project that you created
```
gcloud config set project PROJECT_ID
```

1. Install Terraform on your machine
2. Install Google Cloud CLI
After installing the Google Cloud CLI, initialize it by running the following command:
```bash
gcloud init
```
3. Authentification on gcloud on local shell

``` bash
gcloud auth application-default login
```

## Pre configuration
You must set your postgresql password in `Secret Manager` to use in cloud SQL PostgreSQL db

## Run Terraform

Initiate Terraform
```bash
terraform init
```

Planning Terraform workspace
```bash
terraform plan
```

Apply creating resources in gcp
```bash
terraform apply
```

Remove select resource
```bash
terraform state rm --dry-run google_sql_database.dvd_rental_db
```

Create one resource
```bash
terraform apply --target=google_sql_database.dvd_rental_db
```


Destroy all resources
```bash
terraform destroy plan
```

```bash
terraform apply
```

Or 
```bash
terraform destroy -auto-approve
```

Delete on resource
 
```bash
terraform destroy -target=google_compute_network.vpc
```


Show detail of a specific resource
```bash
terraform state show resouce_type.resource_name
```


## Create a private pool in cloudbuild

Create a private-pool with get address in private-ip-alloc-cb which is a address allocate in vpc 
