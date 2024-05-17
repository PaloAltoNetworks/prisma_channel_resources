terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 5.2.0"
      }
    }

    required_version = ">= 1.3.6"
}

provider "aws" {
   region = "${var.region}"
}
