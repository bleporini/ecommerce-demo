# Configure the Confluent Provider
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.16.0"
    }
    mongodbatlas = {
      source = "mongodb/mongodbatlas"
      version = "1.6.1"
    }
  }
}



provider "mongodbatlas" {
  public_key = var.mongodbatlas_public_key
  private_key  = var.mongodbatlas_private_key
}

resource "mongodbatlas_cluster" "shop" {
  project_id              = var.mongodbatlas_project_id
  name                    = "prestashop"

  # Provider Settings "block"
  provider_name = "TENANT"
  backing_provider_name = var.mongodbatlas_provider
  provider_region_name = var.mongodbatlas_region
  provider_instance_size_name = "M0"
}

resource "mongodbatlas_database_user" "connect" {
  username           = "connect"
  password           = var.mongodbatlas_password
  project_id         = var.mongodbatlas_project_id
  auth_database_name = "admin"

  roles {
    role_name     = "dbAdmin"
    database_name = "commerce"
  }
  roles {
    role_name     = "readWriteAnyDatabase"
    database_name = "admin"
  }
}

resource "mongodbatlas_project_ip_access_list" "all" {
  project_id = var.mongodbatlas_project_id
  cidr_block = "0.0.0.0/0"
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key    # optionally use CONFLUENT_CLOUD_API_KEY env var
  cloud_api_secret = var.confluent_cloud_api_secret # optionally use CONFLUENT_CLOUD_API_SECRET env var
}

resource "confluent_environment" "ecommerce" {
  display_name = "ecommerce"
}

resource "confluent_kafka_cluster" "basic" {
  display_name = "ecommerce-poc"
  availability = "SINGLE_ZONE"
  cloud        = var.cloud
  region       = var.region
  basic {}

  environment {
    id = confluent_environment.ecommerce.id
  }

}

resource "confluent_schema_registry_cluster" "sr" {
  package = "ESSENTIALS"

  environment {
    id = confluent_environment.ecommerce.id
  }

  region {
    # See https://docs.confluent.io/cloud/current/stream-governance/packages.html#stream-governance-regions
    # Schema Registry and Kafka clusters can be in different regions as well as different cloud providers,
    # but you should to place both in the same cloud and region to restrict the fault isolation boundary.
    id = var.sr_region
  }

}

resource "confluent_service_account" "app-manager" {
  display_name = "app-manager"
  description  = "Service account to manage 'inventory' Kafka cluster"

  depends_on = [
    confluent_schema_registry_cluster.sr,
    confluent_kafka_cluster.basic
  ]
  
}


resource "confluent_role_binding" "app-manager-env-admin" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.ecommerce.resource_name
}

resource "confluent_ksql_cluster" "app" {
  display_name = "app"
  csu          = 2
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  credential_identity {
    id = confluent_service_account.app-manager.id
  }
  environment {
    id = confluent_environment.ecommerce.id
  }
  depends_on = [
    confluent_schema_registry_cluster.sr,
    confluent_role_binding.app-manager-env-admin
  ]
}


resource "confluent_api_key" "app-manager-kafka-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
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
      id = confluent_environment.ecommerce.id
    }
  }
}

resource "confluent_kafka_acl" "app-manager-write-on-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = "fa560f9da14"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-manager-create-on-topic-dlq" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = "dlq-lcc"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "CREATE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-manager-write-on-topic-dlq" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = "dlq-lcc"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-manager-read-on-topic-connect" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "GROUP"
  resource_name = "connect-lcc"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_topic" "cart_total_price"{
    topic_name  = "cart_total_price"
    partitions_count = 1

    kafka_cluster {
      id = confluent_kafka_cluster.basic.id
    }
    rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
    credentials {
      key    = confluent_api_key.app-manager-kafka-api-key.id
      secret = confluent_api_key.app-manager-kafka-api-key.secret
   }

  depends_on = [
    confluent_role_binding.app-manager-env-admin
  ]
}

resource "confluent_connector" "sink" {
  environment {
    id = confluent_environment.ecommerce.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_sensitive = {}

  config_nonsensitive = {
  "name"                      ="MongoSink"
  "collection"                ="prestashop"
  "connection.host"           =trimprefix(mongodbatlas_cluster.shop.srv_address, "mongodb+srv://")
  "connection.password"       = var.mongodbatlas_password
  "connection.user"           ="connect"
  "connector.class"           ="MongoDbAtlasSink"
  "database"                  ="commerce"
  "doc.id.strategy"           ="ProvidedInKeyStrategy"
  "input.data.format"         ="JSON_SR"
  "kafka.api.key"             =confluent_api_key.app-manager-kafka-api-key.id
  "kafka.api.secret"          =confluent_api_key.app-manager-kafka-api-key.secret
  "kafka.auth.mode"           ="KAFKA_API_KEY"
  "tasks.max"                 ="1"
  "topics"                    ="cart_total_price"
  }
  depends_on = [
    confluent_kafka_topic.cart_total_price,
    mongodbatlas_database_user.connect
  ]
}

resource "confluent_connector" "source" {
  environment {
    id = confluent_environment.ecommerce.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_sensitive = {}

  config_nonsensitive = {
  "name"                      ="CDC_source"
  "connector.class"           ="MySqlCdcSource"
  "database.hostname"         = var.db_hostname
  "database.include.list"     ="prestashop"
  "database.password"         = var.db_password
  "database.port"             ="3306"
  "database.server.name"      ="fa560f9da14"
  "database.ssl.mode"         ="preferred"
  "database.user"             = "root"
  "json.output.decimal.format"="NUMERIC"
  "kafka.api.key"             =confluent_api_key.app-manager-kafka-api-key.id
  "kafka.api.secret"          =confluent_api_key.app-manager-kafka-api-key.secret
  "kafka.auth.mode"           ="KAFKA_API_KEY"
  "max.batch.size"            ="1000"
  "output.data.format"        ="JSON_SR"
  "output.key.format"         ="JSON"
  "poll.interval.ms"          ="500"
  "snapshot.mode"             ="when_needed"
  "table.include.list"        ="prestashop.ps_cart_product, prestashop.ps_product"
  "tasks.max"                 ="1"
  "database.history.skip.unparseable.ddl"="true"


  }
  depends_on = [
    confluent_role_binding.app-manager-env-admin
  ]

}

