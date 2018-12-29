data "google_compute_image" "unifi-sdn-controller-image" {
  family = "${var.google_compute_instance_image_family}"
  project = "${var.google_compute_instance_image_project}"
}

resource "google_compute_instance" "vm_instance" {
  "boot_disk" {
    initialize_params {
      size = "30"
      image = "${data.google_compute_image.unifi-sdn-controller-image.self_link}"
    }
  }
  machine_type = "${var.google_machine_type}"
  zone = "${var.google_zone}"
  name = "${var.google_instance_name}"
  allow_stopping_for_update = "${var.google_instance_allow_stopping_for_update}"
  tags = ["${var.google_instance_name}"]
  metadata {
    startup-script-url = "gs://${google_storage_bucket.startup-scripts.name}/${google_storage_bucket_object.unif-sdn-controller-startup-script.name}"
  }
  "network_interface" {
    network = "${google_compute_network.default-unifi.name}"
    access_config {
        nat_ip = "${google_compute_address.static.address}"
    }
  }
}
