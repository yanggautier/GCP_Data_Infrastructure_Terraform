dbt_gcp_project:
  target: "{{ env_var('DBT_TARGET', 'dev') }}"
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: "${project_id}"
      dataset: "${dataset}"
      threads: 2
      location: "${region}"

    staging:
      type: bigquery
      method: service-account
      project: "${project_id}"
      dataset: "${dataset}"
      threads: 2
      location: "${region}"

    prod:
      type: bigquery
      method: service-account
      project: "${project_id}"
      dataset: "${dataset}"
      threads: 2
      location: "${region}"