#!/bin/bash
set -e

echo "🚀 SIMPLE PRODUCTION DEPLOY"
echo "=========================="

# Get server IP
SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "44.248.47.186")
echo "📍 Server: $SERVER_IP"

# Cleanup
echo "🧹 Cleanup..."
docker system prune -af --volumes &>/dev/null || true
sudo rm -rf frontend/node_modules frontend/dist &>/dev/null || true

# Build frontend with fixed React version issues
echo "🏗️ Building frontend..."
cd frontend

# Set environment for HTTPS
export VITE_API_BASE_URL="https://www.xn--elfogndedonsoto-zrb.com/api/v1"
export VITE_AWS_REGION="us-west-2"
export VITE_AWS_COGNITO_USER_POOL_ID="us-west-2_bdCwF60ZI"
export VITE_AWS_COGNITO_APP_CLIENT_ID="4i9hrd7srgbqbtun09p43ncfn0"

# Fast npm install with fixed dependencies
rm -rf node_modules package-lock.json &>/dev/null || true
NODE_OPTIONS='--max-old-space-size=512' npm install --legacy-peer-deps --no-audit --no-fund

# Build
NODE_OPTIONS='--max-old-space-size=512' npm run build

# Verify build
if [ ! -f "dist/index.html" ]; then
    echo "❌ Build failed - no index.html"
    exit 1
fi

echo "✅ Frontend built: $(du -sh dist)"
cd ..

# Start with simplified docker-compose
echo "🐳 Starting containers..."
mkdir -p data
docker-compose -f docker-compose.production.yml down &>/dev/null || true
docker-compose -f docker-compose.production.yml up -d --build

echo "⏳ Waiting for containers..."
sleep 15

# Check backend
echo "🔍 Testing backend..."
if curl -s http://localhost:8000/api/v1/health/ &>/dev/null; then
    echo "✅ Backend OK"
else
    echo "❌ Backend failed"
    docker-compose -f docker-compose.production.yml logs backend | tail -10
    exit 1
fi

# Check frontend via nginx
echo "🔍 Testing frontend..."
if curl -s http://localhost/ &>/dev/null; then
    echo "✅ Frontend OK"
else
    echo "❌ Frontend failed"
    docker-compose -f docker-compose.production.yml logs nginx | tail -10
fi

echo ""
echo "🎉 DEPLOY COMPLETE!"
echo "=================="
echo "🌐 Website: http://$SERVER_IP/"
echo "🔧 Backend: http://$SERVER_IP:8000/"
echo "🔐 Admin: http://$SERVER_IP:8000/admin (admin/admin123)"
echo ""
echo "📊 Status:"
docker-compose -f docker-compose.production.yml ps
echo ""
echo "💡 To check logs: docker-compose -f docker-compose.production.yml logs -f"