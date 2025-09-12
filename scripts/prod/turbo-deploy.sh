#!/bin/bash
set -e

echo "🚀 TURBO DEPLOY (Skip npm install if possible)"
echo "=============================================="

# Get server IP
SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "44.248.47.186")
DOMAIN="www.xn--elfogndedonsoto-zrb.com"
echo "📍 Server: $SERVER_IP"
echo "🌐 Domain: $DOMAIN"

# Quick cleanup
echo "🧹 Quick cleanup..."
docker system prune -f --volumes &>/dev/null || true

cd frontend

# Set environment variables
export VITE_API_BASE_URL="https://$DOMAIN/api/v1"
export VITE_AWS_REGION="us-west-2"
export VITE_AWS_COGNITO_USER_POOL_ID="us-west-2_bdCwF60ZI"
export VITE_AWS_COGNITO_APP_CLIENT_ID="4i9hrd7srgbqbtun09p43ncfn0"

echo "   Environment set: $VITE_API_BASE_URL"

# Check if we can skip npm install
if [ -d "node_modules" ] && [ -f "node_modules/.package-lock.json" ]; then
    echo "⚡ Skipping npm install - using existing node_modules"
else
    echo "📦 Installing dependencies..."
    rm -rf node_modules package-lock.json &>/dev/null || true
    
    # Ultra-fast npm
    npm config set fund false
    npm config set audit false
    npm config set progress false
    
    NODE_OPTIONS='--max-old-space-size=512' npm install \
        --legacy-peer-deps \
        --no-audit \
        --no-fund \
        --silent \
        --prefer-offline
fi

# Build
echo "🏗️ Building frontend..."
rm -rf dist &>/dev/null || true
NODE_OPTIONS='--max-old-space-size=512' npm run build

# Verify build
if [ ! -f "dist/index.html" ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Frontend built: $(du -sh dist 2>/dev/null)"
cd ..

# Start containers
echo "🐳 Starting containers..."
mkdir -p data
docker-compose -f docker-compose.production.yml down &>/dev/null || true
docker-compose -f docker-compose.production.yml up -d --build

echo "⏳ Waiting for services..."
sleep 15

# Quick tests
echo "🔍 Testing..."
if curl -s http://localhost:8000/api/v1/health/ &>/dev/null; then
    echo "✅ Backend OK"
else
    echo "❌ Backend failed"
    docker-compose -f docker-compose.production.yml logs backend | tail -5
fi

if curl -s http://localhost/ &>/dev/null; then
    echo "✅ Frontend OK"
else
    echo "❌ Frontend failed"
fi

echo ""
echo "🎉 TURBO DEPLOY COMPLETE!"
echo "========================"
echo "🌐 Website: http://$SERVER_IP/"
echo "🔧 Backend: http://$SERVER_IP:8000/"
echo "📊 Status:"
docker-compose -f docker-compose.production.yml ps