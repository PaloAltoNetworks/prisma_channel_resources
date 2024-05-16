variable "region" { 
	type = string
	default = "us-east1"
}

variable "project_id" {
	type = string
}

variable "secret_name" {
	type = string
	description = "Secret to store - recommend Prisma Cloud Service Account name"
}

variable "initial_access_key" {
	type = string
	sensitive = true
}

variable "initial_secret_key" {
	type = string
	sensitive = true
}

variable "prisma_cloud_console_url" {
	type = string
}

variable "rotation_interval" {
	type = number
	description = "The number of days between automatic scheduled rotations of the secret"
	default = 90

	validation {
		condition     = var.rotation_interval >= 1 && var.rotation_interval <= 365 && floor(var.rotation_interval) == var.rotation_interval
		error_message = "Value must be in the range: 1-365"
	}
}

variable "cloudfunctions2_service_principal" {
	type = string
	description = "Principal to execute cloud functions (run.invoker) and manage secrets (secretmanager.secretAccessor,secretmanager.secretVersionAdder, secretmanager.secretVersionManager)"
}

variable "secretsmanager_service_principal" {
	type = string
	description = "Principal for secrets manager / pubsub interaction"
}

variable "pubsub_topic_name" {
	type = string
	default = "prisma-cloud-key-rolling-topic"
	description = "Name of the pubsub topic for this solution"
}
