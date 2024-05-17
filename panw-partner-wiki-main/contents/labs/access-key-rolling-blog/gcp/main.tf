resource "google_pubsub_topic" "key_rolling_topic" {
  name = "${var.pubsub_topic_name}"
  message_retention_duration = "86600s"
}

resource "google_secret_manager_secret" "key_rolling_secret" {
  secret_id = "${var.secret_name}"

  replication {
    auto {}
  }
  
  topics {
        name = google_pubsub_topic.key_rolling_topic.id
  }
  
  # rotation time is in seconds, but the variable is in days
  rotation {
        rotation_period = "${var.rotation_interval * 86400}s"
        next_rotation_time = timeadd(formatdate("YYYY-MM-01'T'00:00:00Z", timestamp()), "${var.rotation_interval * 86400 }s")
  }
  
  depends_on = [
        google_pubsub_topic.key_rolling_topic,
        google_pubsub_topic_iam_binding.pubsub_role_binding
  ]
}

# IAM Binding for the generated cloud run service
resource "google_cloud_run_service_iam_binding" "function_role_binding" {
  service  = google_cloudfunctions2_function.function.name
  role     = "roles/run.invoker"
  members = [
    "serviceAccount:${var.cloudfunctions2_service_principal}"
  ]

  depends_on = [ google_cloudfunctions2_function.function ]

  lifecycle {
    replace_triggered_by = [ google_cloudfunctions2_function.function ]
  }
}

resource "google_secret_manager_secret_iam_binding" "secret_role_binding" {
  secret_id = google_secret_manager_secret.key_rolling_secret.id
  role     = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${var.cloudfunctions2_service_principal}"
  ]
  depends_on = [ 
        google_secret_manager_secret.key_rolling_secret
  ]  
}

resource "google_secret_manager_secret_iam_binding" "secret_versionadder_role_binding" {
  secret_id = google_secret_manager_secret.key_rolling_secret.id
  role     = "roles/secretmanager.secretVersionAdder"
  members = [
    "serviceAccount:${var.cloudfunctions2_service_principal}"
  ]
  depends_on = [ 
        google_secret_manager_secret.key_rolling_secret
  ]  
}

resource "google_secret_manager_secret_iam_binding" "secret_versionmanager_role_binding" {
  secret_id = google_secret_manager_secret.key_rolling_secret.id
  role     = "roles/secretmanager.secretVersionManager"
  members = [
    "serviceAccount:${var.cloudfunctions2_service_principal}"
  ]
  depends_on = [ 
        google_secret_manager_secret.key_rolling_secret
  ]
}
          
resource "google_pubsub_topic_iam_binding" "pubsub_role_binding" {
  topic = google_pubsub_topic.key_rolling_topic.name
  role = "roles/pubsub.publisher"
  members = [
    "serviceAccount:${var.secretsmanager_service_principal}",
  ]
  
  depends_on = [ 
        google_pubsub_topic.key_rolling_topic
  ]
}

resource "google_secret_manager_secret_version" "key_rolling_secret_version" {
        secret = google_secret_manager_secret.key_rolling_secret.id
        secret_data = jsonencode({"PRISMA_CLOUD_USER"="${var.initial_access_key}","PRISMA_CLOUD_PASS"="${var.initial_secret_key}","PRISMA_CLOUD_CONSOLE_URL"="${var.prisma_cloud_console_url}"})

        depends_on = [ 
                google_cloudfunctions2_function.function,
                google_cloud_run_service_iam_binding.function_role_binding
        ]
}

resource "google_storage_bucket" "key_rolling_function_bucket" {
  name     = "prisma-cloud-keyrolling-function-storage"
  location = var.region
}

data "archive_file" "source" {  
  type = "zip"  
  source_dir = "./resources/" 
  output_path = "./archives/index.zip"
}

resource "google_storage_bucket_object" "archive" {
    source       = data.archive_file.source.output_path
    content_type = "application/zip"

    # Append to the MD5 checksum of the files's content
    # to force the zip to be updated as soon as a change occurs
    name         = "src-${data.archive_file.source.output_md5}.zip"
    bucket       = google_storage_bucket.key_rolling_function_bucket.name

    # Dependencies are automatically inferred so these lines can be deleted
    depends_on   = [
        google_storage_bucket.key_rolling_function_bucket,
        data.archive_file.source
    ]
}

resource "google_cloudfunctions2_function" "function" {
  name = "prisma-cloud-keyrolling-function"
  location = var.region
  description = "Test function for key rolling"

  build_config {
    runtime = "python310"
    entry_point = "rollkey"  # Set the entry point 
    source {
      storage_source {
        bucket = google_storage_bucket.key_rolling_function_bucket.name
        object = google_storage_bucket_object.archive.name
      }
    }
  }

  service_config {
    max_instance_count  = 1
    available_memory    = "256M"
    timeout_seconds     = 60
  }
  
  event_trigger {
    trigger_region = var.region
    event_type = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic = google_pubsub_topic.key_rolling_topic.id
    retry_policy = "RETRY_POLICY_RETRY"
  }
  
  depends_on = [
        google_pubsub_topic.key_rolling_topic
  ]
}
