########################################################################################################
# Generate a random ID so we can avoid this environment colliding with any others you may have created.
########################################################################################################
resource "random_id" "env_id" {
  byte_length = 4
}

########################################################################################################
# Create an Environment
########################################################################################################
resource "confluent_environment" "env" {
  display_name = "${local.env_name}_${random_id.env_id.hex}"
}

########################################################################################################
# Create a Basic cluster in AWS
########################################################################################################
resource "confluent_kafka_cluster" "basic" {
  display_name = local.cluster_name
  availability = "SINGLE_ZONE"
  cloud        = var.cloud
  region       = var.region
  basic {}

  environment {
    id = confluent_environment.env.id
  }
}

########################################################################################################
# Create app-manager Service Account, role bindings, and API key
########################################################################################################
resource "confluent_service_account" "app-manager" {
  display_name = "app-manager-${var.owner.username}-${random_id.env_id.hex}"
  description  = "Service account for provisioning cluster-level resources"
}

resource "confluent_role_binding" "app-manager-rb" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

resource "confluent_api_key" "app-manager-kafka-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API key owned by app-manager service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind
    environment {
      id = confluent_environment.env.id
    }
  }
}

########################################################################################################
# Create a service account & ACLs for connectors
########################################################################################################
resource "confluent_service_account" "connect-sa" {
  display_name = "connect-sa-${var.owner.username}-${random_id.env_id.hex}"
  description  = "Service account for use by managed connectors"
}

resource "confluent_kafka_acl" "connect-sa-describe-cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "CLUSTER"
  principal     = "User:${confluent_service_account.connect-sa.id}"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "connect-sa-write-eventlogs-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  principal     = "User:${confluent_service_account.connect-sa.id}"
  resource_name = "eventlogs"
  pattern_type  = "LITERAL"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "connect-sa-read-all-topics" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  principal     = "User:${confluent_service_account.connect-sa.id}"
  resource_name = "*"
  pattern_type  = "LITERAL"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

########################################################################################################
# Enable a Stream Governance (i.e. Schema Registry) Essentials package
########################################################################################################
data "confluent_schema_registry_region" "sr_region" {
  cloud   = local.cloud
  region  = var.stream_governance_region
  package = "ESSENTIALS"
}
resource "confluent_schema_registry_cluster" "essentials" {
  package = data.confluent_schema_registry_region.sr_region.package
  environment {
    id = confluent_environment.env.id
  }
  region {
    id = data.confluent_schema_registry_region.sr_region.id
  }
}

########################################################################################################
# Create a ksqlDB cluster
########################################################################################################

## service account & role bindings for ksqlDB cluster
resource "confluent_service_account" "app-ksql" {
  display_name = "app-ksql-${var.owner.username}-${random_id.env_id.hex}"
  description  = "Service account to manage ksqlDB cluster"
}

resource "confluent_role_binding" "app-ksql-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-ksql.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

resource "confluent_role_binding" "app-ksql-schema-registry-resource-owner" {
  principal   = "User:${confluent_service_account.app-ksql.id}"
  role_name   = "ResourceOwner"
  crn_pattern = format("%s/%s", confluent_schema_registry_cluster.essentials.resource_name, "subject=*")
}

## the ksqlDB cluster itself
resource "confluent_ksql_cluster" "ksqldb-app1" {
  display_name = "ksqldb-app1"
  csu          = 1
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  credential_identity {
    id = confluent_service_account.app-ksql.id
  }
  environment {
    id = confluent_environment.env.id
  }
  depends_on = [
    confluent_role_binding.app-ksql-kafka-cluster-admin,
    confluent_role_binding.app-ksql-schema-registry-resource-owner,
    confluent_schema_registry_cluster.essentials
  ]
}

########################################################################################################
# Create input topic & source connector
########################################################################################################
resource "confluent_kafka_topic" "eventlogs" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "eventlogs"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_connector" "kinesis-eventlogs" {
  environment {
    id = confluent_environment.env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_sensitive = {}

  config_nonsensitive = {
    "name"                     = "kinesis-eventlogs"
    "connector.class"          = "KinesisSource"
    "tasks.max"                = 1
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.connect-sa.id
    "aws.access.key.id"        = aws_iam_access_key.demo-app.id
    "aws.secret.key.id"        = aws_iam_access_key.demo-app.secret
    "kafka.topic"              = "eventlogs"
    # "output.data.format" = "AVRO"
    "kinesis.region"   = var.region
    "kinesis.stream"   = aws_kinesis_stream.eventlogs.name
    "kinesis.position" = "TRIM_HORIZON"
  }
}

########################################################################################################
# Create output topics for ksqlDB stream processing queries
# (ksqlDB can create these for itself, too, but as a best practice we'll pre-create them here)
########################################################################################################
resource "confluent_kafka_topic" "SUM_PER_SOURCE" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "SUM_PER_SOURCE"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_topic" "COUNT_PER_SOURCE" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "COUNT_PER_SOURCE"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

########################################################################################################
# Create S3 sink connector to sink ksqlDB output topics
########################################################################################################
