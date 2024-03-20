variable "credentials" {
  type = string
}
variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "project" {
  type = string
}

variable "network-name" {
  type = string

}
variable "subnetwebapp-name" {
  type = string

}
variable "subnetdb-name" {
  type = string

}
variable "dest-range" {
  type = string

}
variable "ip-cidr-range-subnetwebapp" {
  type = string
}
variable "ip-cidr-range-subnetdb" {
  type = string
}
variable "webapp-route-name" {
  type = string
}
variable "webapp-route-priority" {
  type = number

}
variable "vpc_names" {
  type = list(string)

}

variable "hop_gateway" {
  type = string
}

variable "firewall-name" {
  type = string

}

variable "target-tag" {
  type = string
}

variable "target-taginstance" {
  type = list(string)
}

variable "port-number" {
  type = string
}

variable "project-name" {
  type = string
}

variable "routing_mode" {
  type = string

}
variable "protocol" {
  type = string
}

variable "instancename" {
  type = string
}

variable "machine_type" {
  type = string
}



variable "mode" {
  type = string
}

variable "imagename" {
  type = string
}

variable "initialize_params_size" {
  type = number
}

variable "initialize_params_type" {
  type = string
}

variable "network_tier" {
  type = string
}

variable "stack_type" {
  type = string
}

variable "queuecount" {
  type = number
}

variable "on_host_maintenance" {
  type = string
}

variable "provisioning_model" {
  type = string
}

variable "sources_ranges" {
  type = string
}

variable "descriptioninstance" {
  type = string
}


variable "global_address_name" {
  type = string
}
variable "global_address_purpose" {
  type = string
}
variable "address_type" {
  type = string
}

variable "prefix_length_ip" {
  type = number
}

variable "networking_service" {
  type = string
}


variable "sqlinstance_name" {
  type = string
}

variable "database_version" {
  type = string
}

variable "tier" {
  type = string
}

variable "availability_type" {
  type = string
}

variable "disk_type" {
  type = string
}

variable "disk_size" {
  type = number
}

variable "database_name" {
  type = string
}
variable "password_length" {
  type = number
}

variable "override_special" {
  type = string
}

variable "sql_user_name" {
  type = string
}

variable "service_account_scope" {
  type = list(string)

}
variable "service_account_id" {
  type = string

}
variable "display_name" {
  type = string

}
variable "record_set_name" {
  type = string

}
variable "record_set_type" {
  type = string

}
variable "record_set_ttl" {
  type = number

}

variable "record_managed_zone" {
  type = string

}

variable "deletion_policy" {
  type = string

}


