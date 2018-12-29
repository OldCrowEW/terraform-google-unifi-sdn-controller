// Module Variables
variable "google_project" {
  default = "unifi-sdn-controller"
}

variable "google_region" {
  default = "us-east1"
}

variable "google_zone" {
  default = "us-east1-b"
}

variable "google_compute_instance_image_family" {
  default = "debian-9"
}

variable "google_compute_instance_image_project" {
  default = "debian-cloud"
}

variable "google_machine_type" {
  default = "f1-micro"
}

variable "google_instance_name" {
  default = "unifi-sdn-controller"
}

variable "google_instance_allow_stopping_for_update" {
  default = "true"
}

variable "google_storage_bucket" {
  default = "unifi-sdn-controller"
}

variable "google_compute_network" {
  default = "unifi"
}