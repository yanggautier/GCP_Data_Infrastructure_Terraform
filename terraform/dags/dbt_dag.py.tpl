from __future__ import annotations
import pendulum

from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from airflow import DAG

DBT_K8S_SERVICE_ACCOUNT_NAME = "{{ dbt_k8s_sa_name }}"
DBT_NAMESPACE = "{{ dbt_namespace }}"

with DAG(
    dag_id="dbt_run_dag", 
    schedule_interval="@daily", 
    start_date=pendulum.datetime(2025, 8, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    tags=["dbt", "kubernetes"]
    ) as dag:
    run_dbt_models = KubernetesPodOperator(
        task_id="run_dbt_models",
        name="dbt-run-pod",
        namespace=DBT_NAMESPACE,
        service_account_name=DBT_K8S_SERVICE_ACCOUNT_NAME,
        image="ghcr.io/dbt-labs/dbt-bigquery:latest"",  # Use this default image at start, then replace with your DBT custom image
        cmds=["dbt"],
        arguments=["run", "--profiles-dir", "/opt/dbt/profiles"],

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
    )