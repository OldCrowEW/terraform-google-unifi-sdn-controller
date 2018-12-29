resource "google_compute_address" "static" {
  name = "ipv4-address"
}

resource "google_compute_network" "default-unifi" {
  name = "${var.google_compute_network}"
}