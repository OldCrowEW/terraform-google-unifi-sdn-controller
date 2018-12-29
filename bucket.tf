resource "google_storage_bucket" "startup-scripts" {
  name = "${var.google_storage_bucket}"
}

resource "google_storage_bucket_object" "unif-sdn-controller-startup-script" {
  name = "${var.google_instance_name}-startup.sh"

  source = "scripts/startup.sh"
  bucket = "${google_storage_bucket.startup-scripts.name}"
}

resource "google_storage_object_acl" "startup-scripts-acl" {
  bucket = "${google_storage_bucket.startup-scripts.name}"
  object = "${google_storage_bucket_object.unif-sdn-controller-startup-script.name}"

  role_entity = [
    "READER:allUsers",
  ]
}
