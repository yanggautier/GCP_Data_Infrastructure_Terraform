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

3. Install Terraform on your machine
4. Install Google Cloud CLI
After installing the Google Cloud CLI, initialize it by running the following command:
```bash
gcloud init
```
5. Authentification on gcloud on local shell

``` bash
gcloud auth application-default login
```

6. Create a Secreate Manager resource, set your postgresql password in `Secret Manager` to use in cloud SQL PostgreSQL db

7. Set all necessary IAM policies at Cloudbuild Service Account 
    - Artifact Registry Administrator
    - Artifact Registry Repository Administrator
    - BigQuery Admin
    - Cloud Build WorkerPool User
    - Cloud Run Admin
    - Cloud SQL Admin
    - Cloud SQL Client
    - Composer Administrator
    - Compute Admin
    - Compute Network Admin
    - Datastream Admin
    - Kubernetes Engine Admin
    - Kubernetes Engine Cluster Admin
    - Kubernetes Engine Developer
    - Logging Admin
    - Logs Viewer
    - Project IAM Admin
    - Secret Manager Admin
    - Security Admin
    - Service Account Admin
    - Service Account User
    - Service Usage Admin
    - Storage Admin
    - Storage Object Admin

8. Set all variables in 'terraform.tfvars' file of environment path or replace in `variables.tf`

9. Create a Cloud Build with name "private-pool" in public network (this allow terraform first time, it's normalement to get an error)

10. Create a Cloudbuild trigger, and set the path of cloudbuild.yaml and variables

11. Run the Cloudbuild trigger

12. Delete the "private-pool" and recreate a "private pool" in private network with get address in private-ip-alloc-cb which is a address allocate in vpc 

13. Rerun the Cloudbuild trigger

14. Import data in the GCS

15. And load 

16. Create a Cloudbuild trigger to clean all resources and run the trigger


## Terraform Commands

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


## Commands for Kubernetes
```bash
#Connect to cluster
gcloud container clusters get-credentials dbt-cluster-<environment> --region <region> --project <project-id>

# Check cluster namaspace state
kubectl get namespace dbt -o yaml

# Delete all namespace finalizers
kubectl patch namespace dbt -p '{"metadata":{"finalizers":[]}}' --type=merge

# Or directly delete the namespace to remove all finalizers
kubectl edit namespace dbt

# Force the delete
kubectl delete namespace dbt --force --grace-period=0 --timeout=30s
```