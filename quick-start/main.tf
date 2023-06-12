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
  cloud        = local.cloud
  region       = local.region
  basic {}

  environment {
    id = confluent_environment.env.id
  }
}

########################################################################################################
# Create app-manager service account for use provisioning cluster-level resources (e.g. creating topics)
########################################################################################################
resource "confluent_service_account" "app-manager" {
  display_name = "app-manager-charmon-${random_id.env_id.hex}"
  description  = "Service account for provisioning cluster-level resources"
}

########################################################################################################
# Create role binding for app-manager to be able to administer cluster-level resources
########################################################################################################
resource "confluent_role_binding" "app-manager-rb" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

########################################################################################################
# Create a Kafka API key owned by app-manager
########################################################################################################
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
# Create a service account for the Datagen connectors with more limited permissions
# necessary to produce data
########################################################################################################
resource "confluent_service_account" "connect-datagen" {
  display_name = "connect-datagen-charmon-${random_id.env_id.hex}"
  description  = "Service account for use by managed Datagen source connectors"
}

########################################################################################################
# Create limited ACLs for connect-datagen role
########################################################################################################
resource "confluent_kafka_acl" "connect-datagen-describe-cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "CLUSTER"
  principal     = "User:${confluent_service_account.connect-datagen.id}"
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

resource "confluent_kafka_acl" "connect-datagen-users-write" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  principal     = "User:${confluent_service_account.connect-datagen.id}"
  resource_name = "users"
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

resource "confluent_kafka_acl" "connect-datagen-pageviews-write" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  principal     = "User:${confluent_service_account.connect-datagen.id}"
  resource_name = "pageviews"
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
# Create the users topic
########################################################################################################
resource "confluent_kafka_topic" "users" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "users"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
  partitions_count = 1

  depends_on = [
    confluent_kafka_cluster.basic
  ]
}

########################################################################################################
# Create the users Datagen connector
########################################################################################################
resource "confluent_connector" "datagen_users" {
  environment {
    id = confluent_environment.env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_sensitive = {}

  config_nonsensitive = {
    "name"               = "DatagenSourceConnector_users"
    "connector.class"    = "DatagenSource"
    "kafka.auth.mode"    = "KAFKA_API_KEY"
    "kafka.api.key"      = confluent_api_key.app-manager-kafka-api-key.id
    "kafka.api.secret"   = confluent_api_key.app-manager-kafka-api-key.secret
    "kafka.topic"        = "users"
    "output.data.format" = "JSON"
    "quickstart"         = "USERS"
    "tasks.max"          = 1
  }
}

########################################################################################################
# Enable a Stream Governance (i.e. Schema Registry) Essentials package
########################################################################################################
data "confluent_schema_registry_region" "sr_region" {
    cloud = local.cloud
    region = local.sr_region
    package = "ADVANCED"
}
resource "confluent_schema_registry_cluster" "sg" {
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
  display_name = "app-ksql-charmon-${random_id.env_id.hex}"
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
  crn_pattern = format("%s/%s", confluent_schema_registry_cluster.sg.resource_name, "subject=*")
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
    confluent_schema_registry_cluster.sg
  ]
}

########################################################################################################
# Create the pageviews topic
########################################################################################################
resource "confluent_kafka_topic" "pageviews" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "pageviews"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
  partitions_count = 1

  depends_on = [
    confluent_kafka_cluster.basic
  ]
}

########################################################################################################
# Create the pageviews Datagen connector
########################################################################################################
resource "confluent_connector" "datagen_pageviews" {
  environment {
    id = confluent_environment.env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_sensitive = {}

  config_nonsensitive = {
    "name"               = "DatagenSourceConnector_pageviews"
    "connector.class"    = "DatagenSource"
    "kafka.auth.mode"    = "KAFKA_API_KEY"
    "kafka.api.key"      = confluent_api_key.app-manager-kafka-api-key.id
    "kafka.api.secret"   = confluent_api_key.app-manager-kafka-api-key.secret
    "kafka.topic"        = "pageviews"
    "output.data.format" = "AVRO"
    "quickstart"         = "PAGEVIEWS"
    "tasks.max"          = 1
  }

  depends_on = [
    confluent_schema_registry_cluster.sg
  ]
}

########################################################################################################
# ksqlDB tables & streams need to be created via the Confluent Cloud web console. These are not
# yet supported by the Confluent CLI and therefore also not by the Terraform provider.
########################################################################################################
