#!/bin/bash
set -e
# Example script to configure Kong Hybrid Mode with a sample service and route
# This demonstrates basic Kong functionality in hybrid mode

echo "🚀 Setting up example Kong Hybrid Mode configuration..."
echo ""

# Wait for Kong Control Plane to be ready
echo "⏳ Waiting for Kong Control Plane to be ready..."
until curl -s http://localhost:8001/status > /dev/null; do
    echo "   Waiting for Kong Admin API..."
    sleep 2
done
echo "✅ Kong Control Plane is ready!"
echo ""

# Wait for Data Planes to be ready
echo "⏳ Waiting for Kong Data Planes to be ready..."
sleep 5
echo "✅ Data Planes should be connected!"
echo ""

# Check cluster status
echo "📊 Checking cluster status..."
CLUSTER_STATUS=$(curl -s http://localhost:8001/clustering/status)
echo "$CLUSTER_STATUS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(f'Connected Data Planes: {len(data.get(\"data\", []))}')" 2>/dev/null || echo "Unable to parse cluster status"
echo ""

# Create a service pointing to httpbin.org
echo "📝 Creating example service..."
SERVICE_RESPONSE=$(curl -s -X POST http://localhost:8001/services \
  --data name=example-service \
  --data url='http://httpbin.org')

if ! SERVICE_ID=$(echo "$SERVICE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null); then
    echo "❌ Failed to create service"
    echo "Response: $SERVICE_RESPONSE"
    exit 1
fi
echo "✅ Service created with ID: $SERVICE_ID"
echo ""

# Create a route for the service
echo "📝 Creating example route..."
ROUTE_RESPONSE=$(curl -s -X POST http://localhost:8001/services/example-service/routes \
  --data 'paths[]=/mock' \
  --data name=example-route)

if ! ROUTE_ID=$(echo "$ROUTE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null); then
    echo "❌ Failed to create route"
    echo "Response: $ROUTE_RESPONSE"
    exit 1
fi
echo "✅ Route created with ID: $ROUTE_ID"
echo ""

# Enable rate limiting plugin
echo "📝 Enabling rate limiting plugin (5 requests per minute)..."
curl -s -X POST http://localhost:8001/services/example-service/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=5" \
  --data "config.policy=local" > /dev/null
echo "✅ Rate limiting enabled"
echo ""

# Add CORS plugin
echo "📝 Enabling CORS plugin..."
curl -s -X POST http://localhost:8001/services/example-service/plugins \
  --data "name=cors" \
  --data "config.origins=*" > /dev/null
echo "✅ CORS enabled"
echo ""

echo "🎉 Configuration complete!"
echo ""
echo "📚 Usage examples:"
echo ""
echo "  Check cluster status:"
echo "  curl http://localhost:8001/clustering/status"
echo ""
echo "  List all services:"
echo "  curl http://localhost:8001/services"
echo ""
echo "  List all routes:"
echo "  curl http://localhost:8001/routes"
echo ""
echo "  Test the proxy via Data Plane 1 (port 8000):"
echo "  curl http://localhost:8000/mock/get"
echo ""
echo "  Test the proxy via Data Plane 2 (port 8100):"
echo "  curl http://localhost:8100/mock/get"
echo ""
echo "  Check rate limiting headers:"
echo "  curl -i http://localhost:8000/mock/get"
echo ""
