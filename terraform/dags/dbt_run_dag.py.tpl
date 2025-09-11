from __future__ import annotations
import pendulum

from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from airflow.operators.bash import BashOperator
from airflow import DAG

# Variables injected by Terraform
DBT_K8S_SERVICE_ACCOUNT_NAME = "${dbt_k8s_sa_name}"
DBT_NAMESPACE = "${dbt_namespace}"
DBT_DEFAULT_IMAGE = "${dbt_default_image}"
DBT_CUSTOM_IMAGE = "${dbt_custom_image}"
FAILURE_EMAIL = "${cloud_composer_admin_email}"

# Default Configuration
default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': pendulum.duration(minutes=5),
}

with DAG(
    dag_id="dbt_run_dag",
    default_args=default_args,
    description="DBT pipeline running on GKE",
    schedule="* 2 * * *", 
    start_date=pendulum.datetime(2025, 8, 1, tz="UTC"),
    email_on_failure= "${cloud_composer_admin_email}"
    catchup=False,
    tags=["dbt", "kubernetes", "bigquery"]
) as dag: 

    # Check which dbt image to use
    determine_dbt_image_task = BashOperator(
        task_id="determine_dbt_image",
        bash_command=f"""
            if gcloud artifacts docker images describe {DBT_CUSTOM_IMAGE} >/dev/null 2>&1; then
                echo "{DBT_CUSTOM_IMAGE}"
            else
                echo "{DBT_DEFAULT_IMAGE}"
            fi
        """,
        do_xcom_push=True,
        get_logs=True,
        log_events_on_failure=True
    )

    # Task to compile DBT models
    compile_dbt_models = KubernetesPodOperator(
        task_id="compile_dbt_models",
        name="dbt-compile-pod",
        namespace=DBT_NAMESPACE,
        service_account_name=DBT_K8S_SERVICE_ACCOUNT_NAME,
        image="{{ determine_dbt_image.xcom_pull(task_ids='determine_dbt_image_task') }}"
        cmds=["dbt"],
        arguments=["compile", "--profiles-dir", "/app/profiles"],
        
        # Configuration of volume_mounts
        volume_mounts=[
            {
                "name": "dbt-profiles",
                "mount_path": "/app/profiles",
                "read_only": True
            }
        ],
        volumes=[
            {
                "name": "dbt-profiles",
                "secret": {
                    "secretName": "dbt-config"
                }
            }
        ],
        
        # Security with Terraform
        security_context={
            "runAsNonRoot": True,
            "runAsUser": 1000,
            "fsGroup": 2000
        },
        container_security_context={
            "allowPrivilegeEscalation": False,
            "readOnlyRootFilesystem": True,
            "capabilities": {
                "drop": ["ALL"]
            }
        },
        
        # Resources configuration 
        resources={
            "requests": {
                "memory": "512Mi",
                "cpu": "250m"
            },
            "limits": {
                "memory": "1Gi",
                "cpu": "500m"
            }
        },
        
        # Automatic clean of pod
        is_delete_operator_pod=True,
        get_logs=True,
        log_events_on_failure=True,
    )

    # Task to execute DBT models
    run_dbt_models = KubernetesPodOperator(
        task_id="run_dbt_models",
        name="dbt-run-pod",
        namespace=DBT_NAMESPACE,
        service_account_name=DBT_K8S_SERVICE_ACCOUNT_NAME,
        image="{{ determine_dbt_image.xcom_pull(task_ids='determine_dbt_image_task') }}",
        cmds=["dbt"],
        arguments=["run", "--profiles-dir", "/app/profiles"],
        
        volume_mounts=[
            {
                "name": "dbt-profiles",
                "mount_path": "/app/profiles",
                "read_only": True
            }
        ],
        volumes=[
            {
                "name": "dbt-profiles",
                "secret": {
                    "secretName": "dbt-config"
                }
            }
        ],
        
        security_context={
            "runAsNonRoot": True,
            "runAsUser": 1000,
            "fsGroup": 2000
        },
        container_security_context={
            "allowPrivilegeEscalation": False,
            "readOnlyRootFilesystem": True,
            "capabilities": {
                "drop": ["ALL"]
            }
        },
        
        resources={
            "requests": {
                "memory": "512Mi", 
                "cpu": "250m"
            },
            "limits": {
                "memory": "2Gi",
                "cpu": "1000m"
            }
        },
        
        is_delete_operator_pod=True,
        get_logs=True,
        log_events_on_failure=True,
    )

    # Task to test DBT models
    test_dbt_models = KubernetesPodOperator(
        task_id="test_dbt_models",
        name="dbt-test-pod",
        namespace=DBT_NAMESPACE,
        service_account_name=DBT_K8S_SERVICE_ACCOUNT_NAME,
        image="ghcr.io/dbt-labs/dbt-bigquery:latest",
        cmds=["dbt"],
        arguments=["test", "--profiles-dir", "/app/profiles"],
        
        volume_mounts=[
            {
                "name": "dbt-profiles",
                "mount_path": "/app/profiles", 
                "read_only": True
            }
        ],
        volumes=[
            {
                "name": "dbt-profiles",
                "secret": {
                    "secretName": "dbt-config"
                }
            }
        ],
        
        security_context={
            "runAsNonRoot": True,
            "runAsUser": 1000,
            "fsGroup": 2000
        },
        container_security_context={
            "allowPrivilegeEscalation": False,
            "readOnlyRootFilesystem": True,
            "capabilities": {
                "drop": ["ALL"]
            }
        },
        
        resources={
            "requests": {
                "memory": "256Mi",
                "cpu": "125m"
            },
            "limits": {
                "memory": "512Mi",
                "cpu": "250m"
            }
        },
        
        is_delete_operator_pod=True,
        get_logs=True,
        log_events_on_failure=True,
    )

    # Order of dependencies
    determine_dbt_image_task >> compile_dbt_models >> run_dbt_models >> test_dbt_models