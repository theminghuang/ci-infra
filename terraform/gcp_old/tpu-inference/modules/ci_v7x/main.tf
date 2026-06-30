# 1 TPU device each
# Runtime: v2-alpha-tpu7-ubuntu2404

data "google_client_config" "config" {
  provider = google-beta
}

resource "google_compute_disk" "tpu_disk" {
  provider = google-beta
  count    = var.instance_count
  name     = "${var.accelerator_type}-ci-${count.index}-${var.project_short_name}-${data.google_client_config.config.zone}-disk"
  size     = var.disk_size
  type     = "hyperdisk-balanced"
}

resource "google_tpu_v2_vm" "tpu_v7x_ci" {
  provider = google-beta
  count    = var.instance_count

  name             = "${var.accelerator_type}-ci-${count.index}-${var.project_short_name}-${data.google_client_config.config.zone}"
  runtime_version  = "v2-alpha-tpu7-ubuntu2404"
  accelerator_type = var.accelerator_type

  labels = {
    vm_name = "${var.accelerator_type}-ci-${count.index}-${var.project_short_name}-${data.google_client_config.config.zone}"
  }

  dynamic "scheduling_config" {
    for_each = var.reserved ? [1] : []
    content {
      reserved = var.reserved
    }
  }

  network_config {
    network             = "projects/${var.project_id}/global/networks/default"
    enable_external_ips = true
  }

  data_disks {
    source_disk = google_compute_disk.tpu_disk[count.index].id
    mode        = "READ_WRITE"
  }

  metadata = {
    "startup-script" = templatefile("${path.module}/../../templates/startup_script.sh.tftpl", {
      mount_disk                 = true
      disk_device                = "/dev/nvme1n1"
      github_app_secret_name     = var.github_app_secret_name
      buildkite_token            = var.buildkite_token_value
      hostname                   = "${var.accelerator_type}-ci-${count.index}-${var.project_short_name}-${data.google_client_config.config.zone}"
      buildkite_tags             = "queue=${var.buildkite_queue_name}"
      huggingface_token          = var.huggingface_token_value
      buildkite_analytics_token  = var.buildkite_analytics_token_value
      tpu_version                = "tpu7x"
      enable_ops_agent           = true
    })
  }
}
