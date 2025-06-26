# Definition of local variables
locals {
  # Environnement configuration fpr Cloud SQL
  env_config = {
    dev = {
      instance_tier           = "db-f1-micro"
      disk_size               = 20
      backup_enabled          = false
      deletion_protection     = false
      max_replication_slots = 10
      max_wal_senders       = 10
    }
    staging = {
      instance_tier           = "db-custom-1-3840"
      disk_size               = 50
      backup_enabled          = true
      deletion_protection     = false
      max_replication_slots = 50
      max_wal_senders       = 50
    }
    prod = {
      instance_tier           = "db-custom-2-4096"
      disk_size               = 100
      backup_enabled          = true
      deletion_protection     = true
      max_replication_slots = 100
      max_wal_senders       = 100
    }
  }

  # Select your actual environmentconfiguration
  current_env = local.env_config[var.environment]
}