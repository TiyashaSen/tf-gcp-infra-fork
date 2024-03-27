terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials)
  project     = var.project
  region      = var.region
  zone        = var.zone

}


resource "google_compute_network" "vpc_network" {
  for_each                        = { for idx, name in var.vpc_names : name => idx }
  name                            = each.key
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = true
}


resource "google_compute_subnetwork" "subnet_webapp" {
  for_each      = google_compute_network.vpc_network
  name          = "${var.subnetwebapp-name}-${each.value.name}"
  network       = each.value.name
  ip_cidr_range = var.ip-cidr-range-subnetwebapp
  region        = var.region
}

resource "google_compute_subnetwork" "subnet_db" {
  for_each      = google_compute_network.vpc_network
  name          = "${var.subnetdb-name}-${each.value.name}"
  network       = each.value.name
  ip_cidr_range = var.ip-cidr-range-subnetdb
  region        = var.region
}

resource "google_compute_route" "webapp-route" {
  for_each         = google_compute_network.vpc_network
  name             = "${var.webapp-route-name}-${each.value.name}"
  dest_range       = var.dest-range
  network          = each.value.name
  next_hop_gateway = var.hop_gateway
  priority         = var.webapp-route-priority
  tags             = [var.target-tag]
}



resource "google_compute_firewall" "rules" {
  for_each      = google_compute_network.vpc_network
  name          = "${var.firewall-name}-${each.value.name}"
  network       = each.value.name
  source_ranges = [var.sources_ranges]
  description   = var.descriptioninstance

  allow {
    protocol = var.protocol
    ports    = var.port-number
  }

  target_tags = [var.target-tag]
}

resource "google_compute_firewall" "rulesdeny" {
  for_each      = google_compute_network.vpc_network
  name          = "${var.deny_name}-${each.value.name}"
  network       = each.value.name
  source_ranges = [var.sources_ranges]
  description   = var.deny_description

  deny {
    protocol = var.protocol
    ports    = [var.deny_port]
  }

  target_tags = [var.target-tag]
}

resource "google_project_iam_binding" "logging_admin" {
  project = var.project
  role    = "roles/logging.admin"

  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_project_iam_binding" "monitoring_metric_writer" {
  project = var.project
  role    = "roles/monitoring.metricWriter"

  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_compute_instance" "devinstance" {
  for_each     = google_compute_subnetwork.subnet_webapp
  name         = var.instancename
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.target-taginstance
  depends_on   = [google_service_account.service_account]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = var.imagename
      size  = var.initialize_params_size
      type  = var.initialize_params_type
    }

    mode = var.mode
  }
  network_interface {
    access_config {
      network_tier = var.network_tier
    }

    queue_count = var.queuecount
    stack_type  = var.stack_type
    subnetwork  = each.value.name
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = var.on_host_maintenance
    preemptible         = false
    provisioning_model  = var.provisioning_model
  }

  metadata_startup_script = templatefile("./scripts/startup-script.sh", {
    psql_username = var.sql_user_name
    psql_password = random_password.password.result
    psql_database = google_sql_database.database[each.key].name
    psql_hostname = google_sql_database_instance.mainpostgres[each.key].private_ip_address
  })

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  service_account {
    email  = google_service_account.service_account.email
    scopes = var.service_account_scope
  }

}
resource "google_compute_global_address" "private_ip_address" {
  for_each      = google_compute_network.vpc_network
  name          = var.global_address_name
  purpose       = var.global_address_purpose
  address_type  = var.address_type
  prefix_length = var.prefix_length_ip
  network       = each.value.name

}
resource "google_service_networking_connection" "servicenetworking" {
  for_each                = google_compute_network.vpc_network
  network                 = each.value.name
  service                 = var.networking_service
  reserved_peering_ranges = [google_compute_global_address.private_ip_address[each.key].name]
  #deletion_policy         = "ABANDON"
}

resource "google_sql_database_instance" "mainpostgres" {
  for_each            = google_compute_network.vpc_network
  name                = var.sqlinstance_name
  database_version    = var.database_version
  region              = var.region
  deletion_protection = false
  depends_on          = [google_service_networking_connection.servicenetworking]


  settings {
    tier = var.tier

    ip_configuration {

      ipv4_enabled    = false
      private_network = each.value.id

    }

    availability_type = var.availability_type
    disk_type         = var.disk_type
    disk_size         = var.disk_size
  }

}

resource "google_sql_database" "database" {
  for_each        = google_sql_database_instance.mainpostgres
  name            = var.database_name
  instance        = each.value.id
  depends_on      = [google_sql_database_instance.mainpostgres]
  deletion_policy = var.deletion_policy

}

resource "random_password" "password" {
  length           = var.password_length
  special          = false
  override_special = var.override_special
}

#users
resource "google_sql_user" "users" {
  for_each        = google_sql_database_instance.mainpostgres
  name            = var.sql_user_name
  instance        = each.value.id
  password        = random_password.password.result
  depends_on      = [google_sql_database.database]
  deletion_policy = var.deletion_policy
}

resource "google_service_account" "service_account" {
  account_id   = var.service_account_id
  display_name = var.display_name
}

# resource "google_service_account" "service_account_cloudfunc" {
#   account_id   = var.service_account_id_cloudfunc
#   display_name = var.display_name_cloudfunc
# }

resource "google_dns_record_set" "example" {
  for_each     = google_compute_instance.devinstance
  name         = var.record_set_name
  type         = var.record_set_type
  ttl          = var.record_set_ttl
  managed_zone = var.record_managed_zone
  rrdatas      = [each.value.network_interface[0].access_config[0].nat_ip]
  depends_on   = [google_compute_instance.devinstance]
}


#needed for cloud function to function and iam binding
resource "google_vpc_access_connector" "connector" {
  for_each      = google_compute_network.vpc_network
  name          = var.connector_name
  ip_cidr_range = var.connector_ip_cidr_range
  project       = var.project
  region        = var.region
  network       = each.value.name
  min_instances = var.connector_min_instances
  max_instances = var.connector_max_instances
  depends_on    = [google_compute_network.vpc_network]
}


resource "google_pubsub_topic_iam_binding" "pubsub_binding" {
  project = var.project
  role    = "roles/pubsub.publisher"
  topic   = google_pubsub_topic.pubsub_topic_verify.name
  members = [
    "serviceAccount:${google_service_account.service_account.email}"
  ]

  depends_on = [google_service_account.service_account, google_pubsub_topic.pubsub_topic_verify]
}


resource "google_cloud_run_v2_service_iam_binding" "binding" {
  for_each = google_cloudfunctions2_function.function
  project  = var.project
  location = var.region
  name     = google_cloudfunctions2_function.function[each.key].name
  role     = "roles/run.invoker"
  members = [
    "serviceAccount:${google_service_account.service_account.email}"
  ]
  depends_on = [google_service_account.service_account, google_cloudfunctions2_function.function]
}

#google_pubsub_topic
resource "google_pubsub_topic" "pubsub_topic_verify" {
  name = var.pubsub_name

  labels = {
    foo = var.foo_label
  }

  message_retention_duration = var.message_retention_duration
}

# data "archive_file" "default" {
#   type        = "zip"
#   output_path = "/tmp/serverlesssource.zip"
#   source_dir  = "./serverlesssource/"
# }

# resource "google_storage_bucket_object" "archive" {
#   name   = "serverlesssource.zip"
#   bucket = "bucket-gcf-source"
#   source = data.archive_file.default.output_path
# }

data "google_storage_bucket_object" "object" {
  name   = var.storage_object_name
  bucket = var.storage_object_bucket
}

#google_cloudfunctions_function
resource "google_cloudfunctions2_function" "function" {
  for_each    = google_vpc_access_connector.connector
  name        = var.cloudfunction_name
  location    = var.cloudfunction_location
  description = var.cloudfunction_description

  build_config {
    runtime     = var.cloudfunction_runtime
    entry_point = var.cloudfunction_entry_point
    source {
      storage_source {
        bucket = var.cloudfunction_bucket
        object = data.google_storage_bucket_object.object.name
      }
    }
  }

  service_config {
    max_instance_count = var.serviceconfig_max_instance_count
    min_instance_count = var.serviceconfig_min_instance_count
    available_memory   = var.serviceconfig_available_memory
    timeout_seconds    = var.serviceconfig_timeout_seconds
    environment_variables = {
      PSQL_DATABASE = google_sql_database.database[each.key].name
      PSQL_USERNAME = var.sql_user_name
      PSQL_PASSWORD = random_password.password.result
      PSQL_HOSTNAME = google_sql_database_instance.mainpostgres[each.key].private_ip_address
    }
    ingress_settings      = var.ingress_settings
    service_account_email = google_service_account.service_account.email

    vpc_connector                 = google_vpc_access_connector.connector[each.key].name
    vpc_connector_egress_settings = var.vpc_egress_settings
  }


  event_trigger {
    trigger_region        = var.trigger_region
    event_type            = var.event_type
    pubsub_topic          = google_pubsub_topic.pubsub_topic_verify.id
    service_account_email = google_service_account.service_account.email
  }

  depends_on = [
    google_vpc_access_connector.connector,
    google_sql_user.users,
    google_sql_database.database
  ]
}
