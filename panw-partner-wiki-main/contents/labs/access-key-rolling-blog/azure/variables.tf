variable "region" { 
        type = string
        default = "eastus"
}

variable "resource_group" {
        type = string
        default = "key-vault-test8"
        description = "Resource group for artifacts"
}

variable "secret_name" {
        type = string
        default = "test-secret"
        description = "Secret to store - recommend Prisma Cloud Service Account name"
}

variable "key_vault_name" {
        type = string
        default = "dschmidtkv0424202412"
        description = "Name of key vault to store secrets"
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
