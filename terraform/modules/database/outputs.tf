output "cloud_sql_private_ip" {
  description = "Private IP address of the Cloud SQL instance."
  value       = google_sql_database_instance.dvd_rental_sql_postgresql.private_ip_address
}

output "postgresql_setup_commands" {
  description = "SQL commands to set up PostgreSQL for Datastream."
  value       = <<-EOF
    -- Connect to your PostgreSQL instance and run these commands:
    -- 1. Create the publication:
    CREATE PUBLICATION datastream_publication FOR ALL TABLES;

    -- 2. Create the replication slot:
    SELECT pg_create_logical_replication_slot('datastream_slot', 'pgoutput');

    -- 3. Verify the setup:
    SELECT slot_name, plugin, slot_type, active FROM pg_replication_slots;
    SELECT pubname FROM pg_publication;

    -- Connection command:
    psql "host=${google_sql_database_instance.dvd_rental_sql_postgresql.private_ip_address} port=5432 dbname=${var.database_name} user=${var.database_user_name}"
    EOF
}


output "time_sleep_wait_for_sql_instance_id" {
  description = "ID of time sleep"
  value = time_sleep.wait_for_sql_instance.id
}