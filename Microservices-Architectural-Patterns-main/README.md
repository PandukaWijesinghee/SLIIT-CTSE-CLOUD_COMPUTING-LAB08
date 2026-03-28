# Microservices Architectural Patterns

This repository contains multiple Spring Boot microservices examples for cloud computing labs, including an event-driven Kafka implementation deployed to Azure Container Apps.

## Repository Overview

This workspace includes several independent examples:

- `API-Gateway/` - standalone gateway sample
- `BackEndServices/` - service-focused microservice examples
- `Kaffka-Example/` - Kafka-based event-driven microservices (main lab target)
- `Spring-boot-intro/` - introductory Spring Boot project

## Main Lab Target: Kaffka-Example

The `Kaffka-Example` module demonstrates an event-driven architecture with:

- `gateway` (port 8080)
- `order-service` (port 8081)
- `inventory-service` (port 8082)
- `notification-service` (port 8083)
- `kafka` broker (port 9092)

### Event Flow

1. Client submits order via gateway (`POST /orders`)
2. `order-service` publishes `order.created`
3. `inventory-service` consumes `order.created` and publishes `inventory.reserved`
4. `order-service` consumes `inventory.reserved` and updates order status
5. `notification-service` consumes events for notifications/logging

## Prerequisites

- Java 21+
- Maven 3.8+
- Docker Desktop
- Azure CLI (for cloud deployment)
- Postman (optional, for API testing)

## Local Run (Kaffka-Example)

From `Kaffka-Example` directory:

1. Build services:

```bash
mvn -f gateway/pom.xml clean package -DskipTests
mvn -f order-service/pom.xml clean package -DskipTests
mvn -f inventory-service/pom.xml clean package -DskipTests
mvn -f notification-service/pom.xml clean package -DskipTests
```

2. Start stack:

```bash
docker-compose up -d
```

3. Smoke test:

```bash
curl http://localhost:8080/actuator/health
```

4. Create order:

```bash
curl -X POST http://localhost:8080/orders \
	-H "Content-Type: application/json" \
	-d '{"orderId":"ORD-1001","sku":"SKU-ABC","quantity":2}'
```

## Azure Deployment

Use the runbook at:

- `Kaffka-Example/AZURE MICROSERVICES + KAFKA DEPLOYM.txt`

Important Azure networking note:

- For internal service-to-service calls in Azure Container Apps, use short service names (for example, `kafka:9092`) instead of full internal FQDNs.

## Postman Testing

Postman assets are in:

- `Kaffka-Example/postman/Kafka-Microservices.postman_collection.json` (local)
- `Kaffka-Example/postman/Kafka-Microservices.postman_environment.json` (local env)
- `Kaffka-Example/postman/Kafka-Microservices-Azure.postman_collection.json` (Azure)
- `Kaffka-Example/postman/Kafka-Microservices-Azure.postman_environment.json` (Azure env)

## Expected Outcomes

After successful setup:

- Gateway health endpoint responds with `UP`
- Order creation returns `202 Accepted`
- Order status transitions from `CREATED` to `INVENTORY_RESERVED` when Kafka flow is healthy

## Notes

- Folder name `Kaffka-Example` is kept as-is to match existing project structure.
- Some modules include prebuilt `target/` outputs; rebuilding is recommended before testing.
