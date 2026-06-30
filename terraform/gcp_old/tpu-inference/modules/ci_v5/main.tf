data "google_secret_manager_secret_version" "buildkite_agent_token_ci_cluster" {
  secret  = "projects/${var.project_id}/secrets/buildkite_agent_token_ci_cluster"
  version = "latest"
}

data "google_secret_manager_secret_version" "huggingface_token" {
  secret  = "projects/${var.project_id}/secrets/huggingface_token"
  version = "latest"
}

locals {
  buildkite_token_value   = data.google_secret_manager_secret_version.buildkite_agent_token_ci_cluster.secret_data
  huggingface_token_value = data.google_secret_manager_secret_version.huggingface_token.secret_data
}

resource "google_compute_disk" "disk_v5" {
  provider = google-beta.us-south1-a
  count    = 7

  name = "tpu-disk-south1-a-${count.index + 1}"
  size = 512
  type = "pd-ssd"
  zone = "us-south1-a"
}

resource "google_tpu_v2_vm" "tpu_v5" {
  provider = google-beta.us-south1-a
  count    = 7
  name     = "vllm-tpu-v5-${count.index + 1}"
  zone     = "us-south1-a"

  runtime_version = "v2-alpha-tpuv5-lite"

  accelerator_type = "v5litepod-1"

  data_disks {
    source_disk = google_compute_disk.disk_v5[count.index].id
    mode        = "READ_WRITE"
  }

  network_config {
    network             = "projects/${var.project_id}/global/networks/default"
    enable_external_ips = true
  }

  metadata = {
    "startup-script" = templatefile("${path.module}/../../templates/startup_script.sh.tftpl", {
      mount_disk                 = true
      disk_device                = "/dev/sdb"
      github_app_secret_name     = var.github_app_secret_name
      buildkite_token            = local.buildkite_token_value
      hostname                   = "vllm-tpu-${count.index}"
      buildkite_tags             = "queue=tpu_v5_queue"
      huggingface_token          = local.huggingface_token_value
      buildkite_analytics_token  = ""
      tpu_version                = "tpu5"
      enable_ops_agent           = false
    })
  }
}
