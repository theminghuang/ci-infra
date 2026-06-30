# 16 nodes for CI cluster
# 1 TPU v6e device each
# Region: us-east5-b
# Type: v6e-1
# Runtime: v2-alpha-tpuv6e

resource "google_compute_disk" "disk_east5_b" {
  provider = google-beta.us-east5-b
  count    = 24

  name = "tpu-disk-east5-b-${count.index}"
  size = 2048
  type = "hyperdisk-balanced"
  zone = "us-east5-b"
}

resource "google_tpu_v2_vm" "tpu_v6_ci" {
  provider = google-beta.us-east5-b
  count    = 24
  name     = "vllm-tpu-v6-ci-${count.index}"
  zone     = "us-east5-b"

  runtime_version = "v2-alpha-tpuv6e"

  accelerator_type = "v6e-1"

  network_config {
    network             = "projects/${var.project_id}/global/networks/default"
    enable_external_ips = true
  }

  data_disks {
    source_disk = google_compute_disk.disk_east5_b[count.index].id
    mode        = "READ_WRITE"
  }

  metadata = {
    "startup-script" = templatefile("${path.module}/../../templates/startup_script.sh.tftpl", {
      mount_disk                 = true
      disk_device                = "/dev/nvme0n2"
      github_app_secret_name     = var.github_app_secret_name
      buildkite_token            = var.buildkite_token_value
      hostname                   = "vllm-tpu-${count.index}"
      buildkite_tags             = "queue=tpu_v6e_queue"
      huggingface_token          = var.huggingface_token_value
      buildkite_analytics_token  = var.buildkite_analytics_token_value
      tpu_version                = "tpu6"
      enable_ops_agent           = false
    })
  }
}
