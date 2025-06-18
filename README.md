

## Settings
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
terraform destroy -auto-approve
```
## 