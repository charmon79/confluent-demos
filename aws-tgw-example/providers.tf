terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.56"
    }
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.51.0"
    }
  }
}

provider "aws" {
  region = var.region

  # ignore_tags {
  #   key_prefixes = [
  #     "divvy",
  #     "confluent-infosec",
  #     "ics"
  #   ]
  # }

  default_tags {
    tags = local.tf_tags
  }
}

locals {
  tf_tags = {
    "tf_owner"       = var.owner.name,
    "tf_owner_email" = var.owner.email,
    "tf_provenance"  = "github.com/charmon79/confluent-cloud-demos/aws-tgw-example",
    "Owner"          = var.owner.username,
  }
}
