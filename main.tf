terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.15.0"
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
  }

  target_tags = [var.target-tag]
}

resource "google_compute_firewall" "default" {
  for_each = google_compute_network.vpc_network
  name     = "${var.newfirewall_name}-${each.value.name}"
  allow {
    protocol = "tcp"
    ports    = ["4000"]
  }
  direction     = "INGRESS"
  network       = each.value.name
  priority      = 610
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = [var.target-tag]
}

resource "google_compute_firewall" "allow_proxy" {
  for_each = google_compute_network.vpc_network
  name     = "${var.allowproxy_name}-${each.value.name}"
  allow {
    ports    = ["4000"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = each.value.name
  priority      = 610
  source_ranges = ["192.168.3.0/24"]
  target_tags   = [var.target-tag]
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

resource "google_compute_address" "default" {
  name         = "address-name"
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
  region       = var.region
}

resource "google_compute_global_address" "default" {
  name         = "global-appserver-ip"
  address_type = "EXTERNAL"
}
resource "google_dns_record_set" "example" {
  name         = var.record_set_name
  type         = var.record_set_type
  ttl          = var.record_set_ttl
  managed_zone = var.record_managed_zone
  #rrdatas      = [each.value.network_interface[0].access_config[0].nat_ip]
  rrdatas    = [google_compute_global_address.default.address]
  depends_on = [google_compute_global_address.default]
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

#loAd balancing starts

# resource "google_compute_region_health_check" "default" {
#   name               = "autohealing-health-check"
#   check_interval_sec = 5
#   healthy_threshold  = 2
#   http_health_check {
#     port_specification = "USE_FIXED_PORT"
#     port               = 4000
#     proxy_header       = "NONE"
#     request_path       = "/healthz"
#   }
#   region              = var.region
#   timeout_sec         = 5
#   unhealthy_threshold = 2
# }

resource "google_compute_health_check" "default" {
  name               = var.health_check_name
  check_interval_sec = var.check_interval_sec
  healthy_threshold  = var.healthy_threshold
  http_health_check {
    port_specification = var.port_specification
    port               = var.health_check_port
    proxy_header       = var.health_check_proxy_header
    request_path       = var.health_check_req_path
  }
  timeout_sec         = var.timeout_sec
  unhealthy_threshold = var.unhealthy_threshold
}
resource "google_compute_region_autoscaler" "foobar" {
  name   = var.autoscaler_name
  region = var.region
  target = google_compute_region_instance_group_manager.foobar.id

  autoscaling_policy {
    max_replicas    = var.autoscaler_max_replicas
    min_replicas    = var.autoscaler_min_replicas
    cooldown_period = var.cooldown_period

    cpu_utilization {
      target = var.autoscaler_target
    }
  }

  depends_on = [google_compute_region_instance_group_manager.foobar]
}
resource "google_compute_region_instance_template" "default" {
  for_each     = google_compute_subnetwork.subnet_webapp
  name         = "appserver-template-${each.value.name}"
  description  = "This template is used to create app server instances."
  machine_type = var.machine_type
  tags         = [var.target-tag]

  can_ip_forward = false

  disk {
    source_image = var.imagename
    boot         = true
    mode         = "READ_WRITE"
    disk_type    = var.disk_type
    disk_size_gb = 100
    #resource_policies = [google_compute_resource_policy.daily_backup.id]
    auto_delete = true
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    stack_type = var.stack_type
    subnetwork = each.value.name
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

  depends_on = [google_service_account.service_account, google_sql_database_instance.mainpostgres, google_sql_database.database]

}


resource "google_compute_region_instance_group_manager" "foobar" {
  name                      = var.groupmanager_name
  region                    = var.region
  distribution_policy_zones = var.distribution_policy_zones

  dynamic "version" {
    for_each = google_compute_region_instance_template.default
    content {
      instance_template = version.value.self_link
      name              = "primary-${version.key}"
    }
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.default.id
    initial_delay_sec = var.initial_delay_sec
  }
  named_port {
    name = var.namedport_name
    port = var.namedport_port
  }

  base_instance_name = var.base_instance_name
  depends_on         = [google_compute_region_instance_template.default, google_compute_health_check.default]
}

# resource "google_compute_region_backend_service" "default" {
#   name                  = "backend-service"
#   region                = var.region
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   health_checks         = [google_compute_region_health_check.default.id]
#   protocol              = "HTTP"
#   port_name             = "backendport"
#   session_affinity      = "NONE"
#   timeout_sec           = 30
#   backend {
#     group           = google_compute_region_instance_group_manager.foobar.instance_group
#     balancing_mode  = "UTILIZATION"
#     capacity_scaler = 1.0
#   }

#   depends_on = [google_compute_region_health_check.default]
# }

resource "google_compute_backend_service" "default" {
  name                  = var.backendname
  load_balancing_scheme = var.bkload_balancing
  health_checks         = [google_compute_health_check.default.id]
  protocol              = var.bkprotocol
  port_name             = var.bkport_name
  session_affinity      = var.bksession_affinity
  timeout_sec           = var.bktimeout_sec
  backend {
    group           = google_compute_region_instance_group_manager.foobar.instance_group
    balancing_mode  = var.bkbalancing_mode
    capacity_scaler = var.bkcapacity_scaler
  }

  depends_on = [google_compute_health_check.default, google_compute_region_instance_group_manager.foobar]
}

# resource "google_compute_region_url_map" "default" {
#   name            = "regional-l7-xlb-map"
#   region          = var.region
#   default_service = google_compute_region_backend_service.default.id
# }

resource "google_compute_url_map" "default" {
  name            = var.urlmap_name
  default_service = google_compute_backend_service.default.id
  depends_on      = [google_compute_backend_service.default]
}

# resource "google_compute_region_target_http_proxy" "default" {
#   name       = "l7-xlb-proxy"
#   region     = var.region
#   url_map    = google_compute_region_url_map.default.id
#   depends_on = [google_compute_region_url_map.default]
# }

resource "google_compute_target_https_proxy" "default" {
  name    = var.httpsproxy_name
  url_map = google_compute_url_map.default.id
  ssl_certificates = [
    google_compute_managed_ssl_certificate.lb_default.name
  ]
  depends_on = [google_compute_url_map.default, google_compute_managed_ssl_certificate.lb_default]
}

# resource "google_compute_region_target_https_proxy" "default" {
#   name    = "l7-xlb-proxy"
#   region  = var.region
#   url_map = google_compute_url_map.default.id
#   ssl_certificates = [
#     google_compute_region_ssl_certificate.default.id
#   ]
#   depends_on = [google_compute_url_map.default, google_compute_region_ssl_certificate.default]
# }

resource "google_compute_subnetwork" "proxy_subnet" {
  for_each      = google_compute_network.vpc_network
  name          = "${var.subnetproxy_name}-${each.value.name}"
  ip_cidr_range = var.pxip_cidr_range
  region        = var.region
  purpose       = var.pxpurpose
  role          = var.pxrole
  network       = each.value.name
  depends_on    = [google_compute_network.vpc_network]
}

# resource "google_compute_forwarding_rule" "default" {
#   for_each   = google_compute_network.vpc_network
#   name       = "l7-xlb-forwarding-rule"
#   depends_on = [google_compute_subnetwork.proxy_subnet, google_compute_target_http_proxy.default, google_compute_network.vpc_network]
#   region     = var.region

#   ip_protocol           = "TCP"
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   port_range            = "80"
#   target                = google_compute_target_http_proxy.default.id
#   network               = each.value.name
#   ip_address            = google_compute_address.default.id
#   network_tier          = "STANDARD"
# }


# resource "google_compute_managed_ssl_certificate" "lb_default" {
#   name = "myservice-ssl-cert"

#   managed {
#     domains = [var.record_set_name]
#   }
# }

resource "google_compute_global_forwarding_rule" "default" {
  for_each   = google_compute_network.vpc_network
  name       = var.fdname
  depends_on = [google_compute_subnetwork.proxy_subnet, google_compute_target_https_proxy.default, google_compute_network.vpc_network, google_compute_global_address.default]


  ip_protocol           = var.fdip_protocol
  load_balancing_scheme = var.fdload_balancing_scheme
  port_range            = var.fdport_range
  target                = google_compute_target_https_proxy.default.id
  #network               = each.value.name
  ip_address = google_compute_global_address.default.id
}


resource "google_compute_managed_ssl_certificate" "lb_default" {
  name = var.sslname

  managed {
    domains = [var.record_set_name]
  }
}

# resource "google_compute_region_ssl_certificate" "default" {
#   region      = var.region
#   name_prefix = "my-certificate-"
#   description = "a description of ssl certificate"
#   private_key = file(".certfile/private.key")
#   certificate = file(".certfile/cloud-cssye_me.crt")

#   lifecycle {
#     create_before_destroy = true
#   }
# }
