terraform {
    required_version = ">= 1.0"

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 6.0"
        }
    }
}

provider "aws" {
    region = "eu-north-1"
    alias = "eu_north_1"
}