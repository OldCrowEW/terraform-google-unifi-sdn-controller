# terraform-google-unifi-sdn-controller

This ia a Terraform module to deploy the Ubiquiti Unifi SDN controller.

This module will create:
* networking
* firewall rules
* bucket
* startup script object in bucket
* launch compute instance with startup script

Everything is in a variable ready for adjustment as needed.

Example use:

    module "unifi-sdn-controller {
        source                                      = "oldcrowew/terraform-google-unifi-sdn-controller"
        google_project                              = "unifi-sdn-controller"
        google_region                               = "us-east1"
        google_zone                                 = "us-east1-b"
        google_compute_instance_image_family        = "debian-9"
        google_compute_instance_image_project       = "debian-cloud"
        google_machine_type                         = "f1-micro"
        google_instance_name                        = "unifi-sdn-controller"
        google_instance_allow_stopping_for_update   = "true"
        google_storage_bucket                       = "unifi-sdn-controller"
        google_compute_network                      = "unifi"
     }