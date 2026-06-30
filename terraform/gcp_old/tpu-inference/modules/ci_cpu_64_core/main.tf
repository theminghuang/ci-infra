data "google_client_config" "gcp_client" {
  provider = google-beta
}

resource "google_compute_instance" "buildkite-agent-instance" {
  provider = google-beta
  count    = var.instance_count
  name     = "vllm-ci-cpu-64-core-${count.index}"

  boot_disk {
    auto_delete = true
    device_name = "vllm-ci-cpu-64-core-${count.index}"

    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2404-noble-amd64-v20251021"
      size  = var.disk_size
      type  = var.disk_type
    }

    mode = "READ_WRITE"
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false
  machine_type        = var.machine_type

  network_interface {
    access_config {
      nat_ip = google_compute_address.static[count.index].address
    }
    subnetwork = "projects/${var.project_id}/regions/${data.google_client_config.gcp_client.region}/subnetworks/default"
  }

  metadata = {
    enable-osconfig  = "TRUE"
    enable-oslogin   = "true"
    "startup-script" = templatefile("${path.module}/../../templates/startup_script.sh.tftpl", {
      mount_disk                 = false
      disk_device                = ""
      github_app_secret_name     = var.github_app_secret_name
      buildkite_token            = var.buildkite_token_value
      hostname                   = "vllm-cpu-64-core-vm${var.resource_suffix}-${count.index}"
      buildkite_tags             = "queue=${var.buildkite_queue_name}"
      huggingface_token          = var.huggingface_token_value
      buildkite_analytics_token  = ""
      tpu_version                = ""
      enable_ops_agent           = false
    })
  }
}

resource "google_compute_address" "static" {
  provider = google-beta
  name     = "vllm-ci-cpu-64-core${var.resource_suffix}-${count.index}-ip"
  count    = var.instance_count
}
