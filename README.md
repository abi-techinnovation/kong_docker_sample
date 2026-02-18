# Kong Gateway Docker Compose Sample

A sample project demonstrating how to run Kong Gateway with PostgreSQL database using Docker Compose.

This repository includes two deployment modes:
- **Traditional Mode**: Single Kong Gateway instance with PostgreSQL database
- **Hybrid Mode**: Control Plane and Data Plane architecture for distributed deployments

## Overview

This project provides complete Kong Gateway setups with:
- **Kong Gateway 3.4**: API Gateway for managing, securing, and routing APIs
- **PostgreSQL 13**: Database for Kong configuration (Control Plane)
- **Kong Migrations**: Automated database schema setup
- **Health Checks**: Ensures services are running properly
- **Persistent Storage**: Database data is stored in Docker volumes
- **Hybrid Mode**: Separate Control Plane and Data Plane instances

## Deployment Modes

### Traditional Mode (docker-compose.yml)

```
┌─────────────────┐
│   Kong Gateway  │ (Ports: 8000, 8001, 8002, 8443, 8444)
│                 │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   PostgreSQL    │ (Port: 5432)
│   Database      │
└─────────────────┘
```

### Hybrid Mode (docker-compose-hybrid.yml)

```
                    ┌──────────────────┐
                    │  Control Plane   │ (Ports: 8001, 8002, 8005, 8006)
                    │  (Admin API)     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │   PostgreSQL     │ (Port: 5432)
                    │   Database       │
                    └──────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Data Plane 1 │    │ Data Plane 2 │    │ Data Plane N │
│ (Proxy)      │    │ (Proxy)      │    │ (Proxy)      │
│ Port: 8000   │    │ Port: 8100   │    │ Port: ...    │
└──────────────┘    └──────────────┘    └──────────────┘
```

## Prerequisites

- Docker (version 20.10 or higher)
- Docker Compose (version 2.0 or higher)

## Quick Start

### Traditional Mode

#### 1. Clone the Repository

```bash
git clone https://github.com/abi-techinnovation/kong_docker_sample.git
cd kong_docker_sample
```

#### 2. Start Kong Gateway

```bash
docker compose up -d
```

This will:
1. Start PostgreSQL database
2. Run Kong migrations to set up the database schema
3. Start Kong Gateway

#### 3. Verify Installation

Check if Kong is running:

```bash
curl -i http://localhost:8001/
```

You should see Kong's Admin API response with status information.

#### 4. (Optional) Run Example Configuration

To quickly set up a sample service with plugins:

```bash
./example-setup.sh
```

This script creates an example service, route, and enables rate limiting and CORS plugins.

### Hybrid Mode

#### 1. Clone the Repository

```bash
git clone https://github.com/abi-techinnovation/kong_docker_sample.git
cd kong_docker_sample
```

#### 2. Start Kong Hybrid Mode

```bash
docker compose -f docker-compose-hybrid.yml up -d
```

This will:
1. Generate cluster certificates for secure CP-DP communication
2. Start PostgreSQL database for Control Plane
3. Run Kong migrations to set up the database schema
4. Start Kong Control Plane (manages configuration)
5. Start Kong Data Plane 1 (handles proxy traffic on port 8000)
6. Start Kong Data Plane 2 (handles proxy traffic on port 8100)

#### 3. Verify Installation

Check Control Plane status:

```bash
curl -i http://localhost:8001/
```

Check cluster status and connected Data Planes:

```bash
curl http://localhost:8001/clustering/status
```

Test Data Plane 1:

```bash
curl -i http://localhost:8000/
```

Test Data Plane 2:

```bash
curl -i http://localhost:8100/
```

#### 4. (Optional) Run Example Configuration

To quickly set up a sample service with plugins:

```bash
./example-setup-hybrid.sh
```

This script creates an example service, route, and enables rate limiting and CORS plugins. The configuration will be automatically synchronized to all Data Planes.

## Service Ports

### Traditional Mode

| Service | Port | Description |
|---------|------|-------------|
| Kong Proxy | 8000 | HTTP proxy for API requests |
| Kong Proxy SSL | 8443 | HTTPS proxy for API requests |
| Kong Admin API | 8001 | RESTful Admin API |
| Kong Admin API SSL | 8444 | HTTPS Admin API |
| Kong Manager | 8002 | Web-based GUI for managing Kong |
| PostgreSQL | 5432 | Database connection |

### Hybrid Mode

| Service | Port | Description |
|---------|------|-------------|
| **Control Plane** | | |
| Kong Admin API | 8001 | RESTful Admin API |
| Kong Manager | 8002 | Web-based GUI for managing Kong |
| Cluster | 8005 | Control Plane cluster communication |
| Cluster Telemetry | 8006 | Telemetry data from Data Planes |
| PostgreSQL | 5432 | Database connection (CP only) |
| **Data Plane 1** | | |
| Kong Proxy | 8000 | HTTP proxy for API requests |
| Kong Proxy SSL | 8443 | HTTPS proxy for API requests |
| **Data Plane 2** | | |
| Kong Proxy | 8100 | HTTP proxy for API requests |
| Kong Proxy SSL | 8543 | HTTPS proxy for API requests |

## Usage Examples

### Check Kong Status

```bash
curl http://localhost:8001/status
```

### Add a Service

Create a service that points to a mock API:

```bash
curl -i -X POST http://localhost:8001/services \
  --data name=example-service \
  --data url='http://mockbin.org'
```

### Add a Route

Create a route for the service:

```bash
curl -i -X POST http://localhost:8001/services/example-service/routes \
  --data 'paths[]=/mock' \
  --data name=example-route
```

### Test the Route

```bash
curl -i http://localhost:8000/mock/request
```

### List Services

```bash
curl http://localhost:8001/services
```

### List Routes

```bash
curl http://localhost:8001/routes
```

## Configuration

### Environment Variables

#### Traditional Mode

The docker-compose configuration supports environment variables for secure credential management. You can customize the configuration by creating a `.env` file:

```bash
cp .env.example .env
```

#### Hybrid Mode

For hybrid mode deployments:

```bash
cp .env.hybrid.example .env
```

Edit the `.env` file to change database credentials or other settings. All sensitive values have default fallbacks, but it's recommended to set custom values in production.

**Important**: Never commit the `.env` file to version control. It's already included in `.gitignore`.

### Kong Configuration

Kong can be further configured through environment variables in the `docker-compose.yml` or `docker-compose-hybrid.yml` file. See the [Kong Configuration Reference](https://docs.konghq.com/gateway/latest/reference/configuration/) for all available options.

### Hybrid Mode Details

In Hybrid Mode:
- **Control Plane (CP)**: Manages configuration via Admin API, stores data in PostgreSQL
- **Data Plane (DP)**: Handles proxy traffic, receives configuration from CP, no database connection
- Communication between CP and DP is secured with automatically generated TLS certificates
- Configuration changes made on CP are automatically synchronized to all connected DPs
- Multiple DPs can be added for load balancing and high availability

## Management

### Traditional Mode

#### View Logs

```bash
# All services
docker compose logs -f

# Kong Gateway only
docker compose logs -f kong

# Database only
docker compose logs -f kong-database
```

#### Stop Services

```bash
docker compose stop
```

#### Start Services

```bash
docker compose start
```

#### Restart Services

```bash
docker compose restart
```

#### Remove Everything

```bash
docker compose down -v
```

**Warning**: The `-v` flag removes volumes, which deletes all database data.

### Hybrid Mode

#### View Logs

```bash
# All services
docker compose -f docker-compose-hybrid.yml logs -f

# Control Plane only
docker compose -f docker-compose-hybrid.yml logs -f kong-cp

# Data Plane 1 only
docker compose -f docker-compose-hybrid.yml logs -f kong-dp-1

# Data Plane 2 only
docker compose -f docker-compose-hybrid.yml logs -f kong-dp-2

# Database only
docker compose -f docker-compose-hybrid.yml logs -f kong-database-cp
```

#### Stop Services

```bash
docker compose -f docker-compose-hybrid.yml stop
```

#### Start Services

```bash
docker compose -f docker-compose-hybrid.yml start
```

#### Restart Services

```bash
docker compose -f docker-compose-hybrid.yml restart
```

#### Check Cluster Status

```bash
curl http://localhost:8001/clustering/status
```

This shows all connected Data Planes and their status.

#### Remove Everything

```bash
docker compose -f docker-compose-hybrid.yml down -v
```

**Warning**: The `-v` flag removes volumes, which deletes all database data and cluster certificates.

## Advanced Usage

### Enable Plugins

Kong supports many plugins for authentication, rate limiting, logging, etc.

Example - Enable rate limiting:

```bash
curl -i -X POST http://localhost:8001/services/example-service/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=5" \
  --data "config.policy=local"
```

### Add Authentication

Example - Enable Key Authentication:

```bash
# Enable the plugin
curl -i -X POST http://localhost:8001/services/example-service/plugins \
  --data "name=key-auth"

# Create a consumer
curl -i -X POST http://localhost:8001/consumers \
  --data "username=demo-user"

# Create a key for the consumer
curl -i -X POST http://localhost:8001/consumers/demo-user/key-auth \
  --data "key=my-secret-key"

# Test with the key
curl -i http://localhost:8000/mock/request \
  -H 'apikey: my-secret-key'
```

## Troubleshooting

### Port Conflicts

If you encounter port conflicts, you can change the port mappings in `docker-compose.yml` or `docker-compose-hybrid.yml`:

```yaml
ports:
  - "9000:8000"  # Change 9000 to your preferred port
```

### Database Connection Issues

Check if the database is healthy:

```bash
# Traditional mode
docker compose ps

# Hybrid mode
docker compose -f docker-compose-hybrid.yml ps
```

View database logs:

```bash
# Traditional mode
docker compose logs kong-database

# Hybrid mode
docker compose -f docker-compose-hybrid.yml logs kong-database-cp
```

### Hybrid Mode: Data Plane Not Connecting

Check Control Plane logs:

```bash
docker compose -f docker-compose-hybrid.yml logs kong-cp
```

Check Data Plane logs:

```bash
docker compose -f docker-compose-hybrid.yml logs kong-dp-1
docker compose -f docker-compose-hybrid.yml logs kong-dp-2
```

Verify cluster certificates exist:

```bash
docker compose -f docker-compose-hybrid.yml exec kong-cp ls -la /certs/
```

Check cluster status:

```bash
curl http://localhost:8001/clustering/status
```

### Reset Everything

To start fresh:

```bash
# Traditional mode
docker compose down -v
docker compose up -d

# Hybrid mode
docker compose -f docker-compose-hybrid.yml down -v
docker compose -f docker-compose-hybrid.yml up -d
```

## Resources

- [Kong Gateway Documentation](https://docs.konghq.com/gateway/latest/)
- [Kong Hybrid Mode Documentation](https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/)
- [Kong Admin API Reference](https://docs.konghq.com/gateway/latest/admin-api/)
- [Kong Plugin Hub](https://docs.konghq.com/hub/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## License

This is a sample project for demonstration purposes.