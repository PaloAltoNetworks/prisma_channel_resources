output "pubsub_topic_name" {
  description = "Name of the pubsub topic that will handle the key rolling events"
  value       = google_pubsub_topic.key_rolling_topic.name
}

output "secret_id" {
  description = "Full path to the secret"
  value       = google_secret_manager_secret.key_rolling_secret.id
}
