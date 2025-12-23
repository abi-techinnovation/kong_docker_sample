# Kong Gateway Docker Compose Sample

A sample project demonstrating how to run Kong Gateway with PostgreSQL database using Docker Compose.

## Overview

This project provides a complete Kong Gateway setup with:
- **Kong Gateway 3.4**: API Gateway for managing, securing, and routing APIs
- **PostgreSQL 13**: Database for Kong configuration
- **Kong Migrations**: Automated database schema setup
- **Health Checks**: Ensures services are running properly
- **Persistent Storage**: Database data is stored in Docker volumes

## Architecture

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

## Prerequisites

- Docker (version 20.10 or higher)
- Docker Compose (version 2.0 or higher)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/abi-techinnovation/kong_docker_sample.git
cd kong_docker_sample
```

### 2. Start Kong Gateway

```bash
docker-compose up -d
```

This will:
1. Start PostgreSQL database
2. Run Kong migrations to set up the database schema
3. Start Kong Gateway

### 3. Verify Installation

Check if Kong is running:

```bash
curl -i http://localhost:8001/
```

You should see Kong's Admin API response with status information.

## Service Ports

| Service | Port | Description |
|---------|------|-------------|
| Kong Proxy | 8000 | HTTP proxy for API requests |
| Kong Proxy SSL | 8443 | HTTPS proxy for API requests |
| Kong Admin API | 8001 | RESTful Admin API |
| Kong Admin API SSL | 8444 | HTTPS Admin API |
| Kong Manager | 8002 | Web-based GUI for managing Kong |
| PostgreSQL | 5432 | Database connection |

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

You can customize the configuration by creating a `.env` file:

```bash
cp .env.example .env
```

Edit the `.env` file to change database credentials or other settings.

### Kong Configuration

Kong can be further configured through environment variables in the `docker-compose.yml` file. See the [Kong Configuration Reference](https://docs.konghq.com/gateway/latest/reference/configuration/) for all available options.

## Management

### View Logs

```bash
# All services
docker-compose logs -f

# Kong Gateway only
docker-compose logs -f kong

# Database only
docker-compose logs -f kong-database
```

### Stop Services

```bash
docker-compose stop
```

### Start Services

```bash
docker-compose start
```

### Restart Services

```bash
docker-compose restart
```

### Remove Everything

```bash
docker-compose down -v
```

**Warning**: The `-v` flag removes volumes, which deletes all database data.

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

If you encounter port conflicts, you can change the port mappings in `docker-compose.yml`:

```yaml
ports:
  - "9000:8000"  # Change 9000 to your preferred port
```

### Database Connection Issues

Check if the database is healthy:

```bash
docker-compose ps
```

View database logs:

```bash
docker-compose logs kong-database
```

### Reset Everything

To start fresh:

```bash
docker-compose down -v
docker-compose up -d
```

## Resources

- [Kong Gateway Documentation](https://docs.konghq.com/gateway/latest/)
- [Kong Admin API Reference](https://docs.konghq.com/gateway/latest/admin-api/)
- [Kong Plugin Hub](https://docs.konghq.com/hub/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## License

This is a sample project for demonstration purposes.