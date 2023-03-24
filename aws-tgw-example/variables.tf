locals {
  env_name     = "${var.owner.username}-cloud-etl-example"
  cluster_name = "${var.owner.username}-basic"
  description  = "Created via Terraform based on CC Cloud ETL Example tutorial"
  cloud        = "AWS"
}

variable "owner" {
  type = map(any)
  default = {
    name     = "Chris Harmon"
    username = "charmon"
    email    = "charmon@confluent.io"
  }
}

variable "cloud" {
  description = "Cloud provider on which to create resources"
  default     = "AWS"
}

variable "region" {
  description = "Cloud provider's region in which to create resources"
  default     = "us-east-2"
}

########################################################################################################
# Stream Governance regions have special region IDs in Confluent Cloud as documented at:
# - https://docs.confluent.io/cloud/current/stream-governance/packages.html#sr-regions
# 
# To make the code easier to understand, we'll use the cloud provider's region name here,
# and use it with the confluent_schema_registry_region data object to look up Confluent's
# Stream Governance region ID.
########################################################################################################
variable "stream_governance_region" {
  description = "Cloud provider's region in which to deploy Schema Registry/Stream Governance"
  default     = "us-east-2"
}
