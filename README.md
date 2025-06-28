



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
terraform destroy -target=google_compute_network.datastream_vpc
```


Show detail of a specific resource
```bash
terraform state show resouce_type.resource_name
```




## Add publication in bd PostgreSQL after deploiement

```sql
CREATE PUBLICATION dvd_rental_publication FOR ALL TABLES;
SELECT pg_create_logical_replication_slot('dvd_rental_slot', 'pgoutput');
```

```mermaid
graph LR
    subgraph Google Cloud Project dbt-project-dvd-rent
        subgraph VPC Network datastream-vpc
            direction LR

            subgraph Subnets
                DS_SUBNET["Subnetwork: datastream-subnet<br/>(10.2.0.0/24)"]
                PRIVATE_IP_ALLOC["Reserved Range: private-ip-alloc<br/>(VPC Peering for Cloud SQL)"]
                PRIVATE_IP_ALLOC_CB["Reserved Range: private-ip-alloc-cb<br/>(VPC Peering for Cloud Build Private Pool)"]
            end

            FW_DS_SQL("Firewall: allow-datastream-to-sql<br/>TCP 5432 Ingress")
            FW_INTERNAL("Firewall: allow-internal-vpc<br/>TCP/UDP/ICMP 10.0.0.0/8")

            DS_SUBNET --> FW_DS_SQL
            FW_DS_SQL -.-> CLOUD_SQL
            DS_SUBNET --> FW_INTERNAL
            FW_INTERNAL -.-> DS_SUBNET

            PEERING_SVC_NET("Service Networking Connection<br/>(servicenetworking.googleapis.com)")
            PEERING_SVC_NET --- PRIVATE_IP_ALLOC
            PEERING_SVC_NET --- PRIVATE_IP_ALLOC_CB

            CLOUD_SQL["Cloud SQL Instance:<br/>dvd-rental-dev-instance<br/>(PostgreSQL 15 - Private IP)"]
            PEERING_SVC_NET -- VPC Peering --> CLOUD_SQL

            subgraph Datastream Private Connection datastream-connection-dev
                DS_PRIVATE_CONN["Datastream Internal Network<br/>(10.3.0.0/24)"]
            end

            DS_PRIVATE_CONN -- Peered to --> PEERING_SVC_NET

        end

        subgraph Cloud Build Private Pool your-pool-name
            CB_PRIVATE_POOL["Cloud Build Worker Pool"]
            CB_PRIVATE_POOL -- Uses Private IP --> PEERING_SVC_NET
        end

        subgraph Datastream Services
            DS_SA["Service Account: datastream-service-account<br/>(Roles: datastream.admin, bigquery.dataEditor, cloudsql.client, secretmanager.secretAccessor)"]
            DS_CP_SOURCE["Connection Profile: postgresql-source-dev<br/>(Connects to Cloud SQL via Private Connection)"]
            DS_CP_DEST["Connection Profile: bigquery-destination-dev<br/>(Connects to BigQuery via Private Connection)"]
            DS_STREAM["Stream: postgres-to-bigquery-dev<br/>(Source: DS_CP_SOURCE, Dest: DS_CP_DEST)"]

            DS_SA -- Used by --> DS_CP_SOURCE
            DS_SA -- Used by --> DS_CP_DEST
            DS_CP_SOURCE -- Data Flow --> DS_STREAM
            DS_CP_DEST -- Data Flow --> DS_STREAM
            DS_PRIVATE_CONN -- Used by --> DS_CP_SOURCE
            DS_PRIVATE_CONN -- Used by --> DS_CP_DEST
        end

        subgraph BigQuery
            BQ_DATASET["BigQuery Dataset: dvd_rental_bigquery_dataset"]
            DS_STREAM --> BQ_DATASET
        end

        subgraph Secret Manager
            SM_DB_PASSWORD["Secret: your-db-password-secret<br/>(Database Password)"]
        end

        subgraph Cloud Storage
            GCS_STATE["Bucket: state-files-dev<br/>(Terraform State Backend)"]
            GCS_DBT["Bucket: dbt-bucket"]
            GCS_DVD["Bucket: dvd-rental-bucket"]
        end

        subgraph Orchestration
            AR_REPO["Artifact Registry: dbt-repo"]
            CR_SERVICE["Cloud Run: dbt-runner"]
            COMPOSER_ENV["Composer Environment: dbt-orchestration"]
            COMPOSER_SA["Composer Service Account"]

            CR_SERVICE -- Deploys from --> AR_REPO
            COMPOSER_ENV -- Orchestrates --> CR_SERVICE
            COMPOSER_ENV -- Uses --> COMPOSER_SA
        end

        SM_DB_PASSWORD -- Accessed by --> CLOUD_SQL
        SM_DB_PASSWORD -- Accessed by --> DS_SA
    end
```