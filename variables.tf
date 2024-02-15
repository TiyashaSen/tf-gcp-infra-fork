variable "credentials" {
  type = string
}
variable "region" {
  type = string
}

variable "zon" {
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
