# Port list retrieved 29DEC18 - https://help.ubnt.com/hc/en-us/articles/218506997-UniFi-Ports-Used

resource "google_compute_firewall" "unifi-stun" {
  name = "${var.google_instance_name}-unifi-stun"
  network = "${google_compute_network.default-unifi.name}"

  allow {
    protocol = "udp"
    ports = ["3478"]
  }
  target_tags = ["${var.google_instance_name}"]
  description = "Port used for STUN"
}

resource "google_compute_firewall" "unifi-inform" {
  name = "${var.google_instance_name}-unifi-inform"
  network = "${google_compute_network.default-unifi.name}"

  allow {
    protocol = "tcp"
    ports = ["8080"]
  }
  target_tags = ["${var.google_instance_name}"]
  description = "Port for device and controller communication"
}

resource "google_compute_firewall" "unifi-gui-api" {
  name = "${var.google_instance_name}-unifi-gui-api"
  network = "${google_compute_network.default-unifi.name}"

  allow {
    protocol = "tcp"
    ports = ["8443"]
  }
  target_tags = ["${var.google_instance_name}"]
  description = "Port used for controller GUI/API as seen in a web browser"
}

resource "google_compute_firewall" "unifi-http-redirect" {
  name = "${var.google_instance_name}-unifi-http-redirect"
  network = "${google_compute_network.default-unifi.name}"

  allow {
    protocol = "tcp"
    ports = ["8880"]
  }
  target_tags = ["${var.google_instance_name}"]
  description = "Port used for HTTP portal redirection"
}

resource "google_compute_firewall" "unifi-https-redirect" {
  name = "${var.google_instance_name}-unifi-https-redirect"
  network = "${google_compute_network.default-unifi.name}"

  allow {
    protocol = "tcp"
    ports = ["8843"]
  }
  target_tags = ["${var.google_instance_name}"]
  description = "Port used for HTTP portal redirection"
}

resource "google_compute_firewall" "unifi-throughput" {
  name = "${var.google_instance_name}-unifi-throughput"
  network = "${google_compute_network.default-unifi.name}"

  allow {
    protocol = "tcp"
    ports = ["6789"]
  }
  target_tags = ["${var.google_instance_name}"]
  description = "Port used for UniFi mobile speed test"
}
