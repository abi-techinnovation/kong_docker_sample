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
echo "⏳ Waiting for Kong Data Planes to connect..."
MAX_WAIT=30
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    DP_COUNT=$(curl -s http://localhost:8001/clustering/status 2>/dev/null | grep -o '"hostname"' | wc -l || echo 0)
    if [ "$DP_COUNT" -ge 2 ]; then
        echo "✅ Data Planes connected successfully!"
        break
    fi
    echo "   Waiting for Data Planes to connect... ($WAITED/$MAX_WAIT seconds)"
    sleep 2
    WAITED=$((WAITED + 2))
done

if [ "$DP_COUNT" -lt 2 ]; then
    echo "⚠️  Warning: Expected 2 Data Planes, found $DP_COUNT. Continuing anyway..."
fi
echo ""

# Check cluster status
echo "📊 Checking cluster status..."
CLUSTER_STATUS=$(curl -s http://localhost:8001/clustering/status)
if command -v python3 > /dev/null 2>&1; then
    echo "$CLUSTER_STATUS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(f'Connected Data Planes: {len(data)}')" 2>/dev/null || echo "$CLUSTER_STATUS" | grep -o '"hostname"' | wc -l | xargs echo "Connected Data Planes:"
else
    echo "$CLUSTER_STATUS" | grep -o '"hostname"' | wc -l | xargs echo "Connected Data Planes:"
fi
echo ""

# Create a service pointing to httpbin.org
echo "📝 Creating example service..."
SERVICE_RESPONSE=$(curl -s -X POST http://localhost:8001/services \
  --data name=example-service \
  --data url='http://httpbin.org')

if command -v python3 > /dev/null 2>&1; then
    SERVICE_ID=$(echo "$SERVICE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
else
    # Fallback: extract id using grep/sed if python3 is not available
    SERVICE_ID=$(echo "$SERVICE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | sed 's/"id":"//;s/"//')
fi

if [ -z "$SERVICE_ID" ]; then
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

if command -v python3 > /dev/null 2>&1; then
    ROUTE_ID=$(echo "$ROUTE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
else
    # Fallback: extract id using grep/sed if python3 is not available
    ROUTE_ID=$(echo "$ROUTE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | sed 's/"id":"//;s/"//')
fi

if [ -z "$ROUTE_ID" ]; then
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
