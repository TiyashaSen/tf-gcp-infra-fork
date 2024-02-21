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

variable "zone" {
  type = string
}


variable "mode" {
  type = string
}

variable "imagename" {
  type = string
}
