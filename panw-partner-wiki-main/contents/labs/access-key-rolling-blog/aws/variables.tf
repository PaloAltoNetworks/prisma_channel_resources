variable "region" { 
        type = string
        default = "us-east-1"

        validation {
                condition = can(regex("[a-z][a-z]-[a-z]+-[1-9]", var.region))
                error_message = "Must be valid AWS region name."
        }
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

variable "s3_bucket_for_layer" {
        type = string
        description = "S3 Bucket for the custom lambda layer with the prismacloud-sdk installed"
        default = "rotating-prisma-cloud-access-keys-blog"
}

variable "s3_key_for_layer" {
        type = string
        description = "S3 object for the custom lambda layer with the prismacloud-sdk installed"
        default = "aws/lambda/layers/prismacloud-sdk/prismacloud-sdk.zip"
}

variable "initial_access_key" {
        type = string
        sensitive = true
	description = "The initial access key to import into the Secret"
}

variable "initial_secret_key" {
        type = string
        sensitive = true
	description = "The initial secret key to import into the Secret"
}

variable "prisma_cloud_console_url" {
        type = string
	description = "The Prisma Cloud console URL (for example - https://api.prismacloud.io)"
}

variable "secret_name" {
        type = string
        description = "Name of the Secret to store - recommend using the Prisma Cloud Service Account name"
}
