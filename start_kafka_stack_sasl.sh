#!/bin/bash

# Pull latest images
docker pull confluentinc/cp-zookeeper:latest
docker pull confluentinc/cp-kafka:latest
docker pull confluentinc/cp-schema-registry:latest

# Create SASL JAAS config files
cat > zookeeper_jaas.conf <<EOF
Server {
  org.apache.zookeeper.server.auth.SASLAuthenticationProvider required
  username="zookeeper"
  password="zookeeper-secret";
};
EOF

cat > kafka_jaas.conf <<EOF
KafkaServer {
  org.apache.kafka.common.security.plain.PlainLoginModule required
  username="admin"
  password="admin-secret"
  user_admin="admin-secret"
  user_user="user-secret";
};
EOF

cat > schema_registry_jaas.conf <<EOF
SchemaRegistry {
  org.apache.kafka.common.security.plain.PlainLoginModule required
  username="schemaregistry"
  password="schemaregistry-secret";
};
EOF

# Start Zookeeper
nohup docker run -d --name zookeeper \
  -p 2181:2181 \
  -e ZOOKEEPER_CLIENT_PORT=2181 \
  -e ZOOKEEPER_TICK_TIME=2000 \
  -e ZOOKEEPER_AUTH_PROVIDER_SASL=org.apache.zookeeper.server.auth.SASLAuthenticationProvider \
  -v "$(pwd)/zookeeper_jaas.conf:/etc/zookeeper/zookeeper_jaas.conf" \
  confluentinc/cp-zookeeper:latest \
  2>&1 | sed 's/^/[zookeeper] /' >> servers.out &

        # Start Kafka
        nohup docker run -d --name kafka \
          -p 9092:9092 \
          -e KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181 \
          -e KAFKA_LISTENERS=SASL_PLAINTEXT://0.0.0.0:9092 \
          -e KAFKA_ADVERTISED_LISTENERS=SASL_PLAINTEXT://localhost:9092 \
          -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=SASL_PLAINTEXT:SASL_PLAINTEXT \
          -e KAFKA_INTER_BROKER_LISTENER_NAME=SASL_PLAINTEXT \
          -e KAFKA_SASL_ENABLED_MECHANISMS=PLAIN \
          -e KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL=PLAIN \
          -e KAFKA_PROCESS_ROLES=broker \
          -e KAFKA_NODE_ID=1 \
          -e CLUSTER_ID=kafka-cluster-1 \
          -e KAFKA_OPTS="-Djava.security.auth.login.config=/etc/kafka/kafka_jaas.conf" \
          -v "$(pwd)/kafka_jaas.conf:/etc/kafka/kafka_jaas.conf" \
          confluentinc/cp-kafka:latest \
          2>&1 | sed 's/^/[kafka] /' >> servers.out &# Start Schema Registry
nohup docker run -d --name schema-registry \
          -p 8081:8081 \
          -e SCHEMA_REGISTRY_HOST_NAME=schema-registry \
          -e SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=SASL_PLAINTEXT://kafka:9092 \
          -e SCHEMA_REGISTRY_KAFKASTORE_SECURITY_PROTOCOL=SASL_PLAINTEXT \
          -e SCHEMA_REGISTRY_KAFKASTORE_SASL_MECHANISM=PLAIN \
          -e SCHEMA_REGISTRY_OPTS="-Djava.security.auth.login.config=/etc/schema-registry/schema_registry_jaas.conf" \
          -v "$(pwd)/schema_registry_jaas.conf:/etc/schema-registry/schema_registry_jaas.conf" \
          confluentinc/cp-schema-registry:latest \
          2>&1 | sed 's/^/[schema-registry] /' >> servers.out &