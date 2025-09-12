from __future__ import annotations
import pendulum

from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from airflow.operators.bash import BashOperator
from airflow import DAG


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
    on_failure_callback="${cloud_composer_admin_email}",
    catchup=False,
    tags=["dbt", "kubernetes", "bigquery"]
) as dag: 

    # Check which dbt image to use
    determine_dbt_image_task = BashOperator(
        task_id="determine_dbt_image",
        bash_command=f"""
            if gcloud artifacts docker images describe ${dbt_custom_image} >/dev/null 2>&1; then
                echo "${dbt_custom_image}"
            else
                echo "${dbt_default_image}"
            fi
        """,
        do_xcom_push=True
    )

    # Retrieve the image name from XCom
    # This ensures the image name is available before being used in subsequent tasks
    dbt_image_name = determine_dbt_image_task.output

    # Task to compile DBT models
    compile_dbt_models = KubernetesPodOperator(
        task_id="compile_dbt_models",
        name="dbt-compile-pod",
        namespace="${dbt_namespace}",
        service_account_name="${dbt_k8s_sa_name}",
        image=dbt_image_name,
        cmds=["dbt"],
        arguments=["run",  "--vars", "{'bronze_dataset': '${bronze_dataset}', 'silver_dataset': '${silver_dataset}', 'gold_dataset': '${gold_dataset}'}", "--profiles-dir", "/app/profiles"],

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
            "request": {
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
        namespace="${dbt_namespace}",
        service_account_name="${dbt_k8s_sa_name}",
        image=dbt_image_name,
        cmds=["dbt"],
        arguments=["run",  "--vars", "{'bronze_dataset': '${bronze_dataset}', 'silver_dataset': '${silver_dataset}', 'gold_dataset': '${gold_dataset}'}", "--profiles-dir", "/app/profiles"],

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
            "request": {
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
        namespace="${dbt_namespace}",
        service_account_name="${dbt_k8s_sa_name}",
        image=dbt_image_name,
        cmds=["dbt"],
        arguments=["run",  "--vars", "{'bronze_dataset': '${bronze_dataset}', 'silver_dataset': '${silver_dataset}', 'gold_dataset': '${gold_dataset}'}", "--profiles-dir", "/app/profiles"],

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
            "request": {
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