#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ⚡ RESTAURANT WEB - ULTRA FAST DEPLOY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

echo "⚡ ULTRA FAST DEPLOYMENT"
echo "======================="

# Get server IP
SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "44.248.47.186")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🧹 AGGRESSIVE CLEANUP 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🧹 Aggressive cleanup..."
docker system prune -af --volumes &>/dev/null || true
sudo rm -rf frontend/node_modules frontend/dist backend/__pycache__ &>/dev/null || true
sudo rm -rf /tmp/* /var/cache/apt/* &>/dev/null || true
echo "📊 Disk: $(df -h . | tail -1 | awk '{print $4}')"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🏗️ BUILD FRONTEND LOCALLY (FASTER)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🏗️ Building frontend locally..."

# Install Node.js if needed
if ! command -v node &>/dev/null; then
    echo "   Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

cd frontend

# Set environment variables
export VITE_API_BASE_URL="http://$SERVER_IP:8000/api/v1"
export VITE_AWS_REGION="us-west-2"
export VITE_AWS_COGNITO_USER_POOL_ID="us-west-2_bdCwF60ZI"
export VITE_AWS_COGNITO_APP_CLIENT_ID="4i9hrd7srgbqbtun09p43ncfn0"

# Build with memory optimization
echo "   npm install..."
NODE_OPTIONS='--max-old-space-size=512' npm install --prefer-offline &>/dev/null

echo "   npm build..."
NODE_OPTIONS='--max-old-space-size=512' npm run build &>/dev/null

# Clean up immediately
rm -rf node_modules &>/dev/null || true
npm cache clean --force &>/dev/null || true

if [ ! -f "dist/index.html" ]; then
    echo "❌ Frontend build failed"
    exit 1
fi

echo "   ✅ Frontend built"
cd ..

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🐳 ULTRA FAST DOCKER BUILD
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🐳 Building containers..."
mkdir -p data

# Build only backend (much faster)
echo "   Building backend container..."
docker-compose -f docker-compose.simple.yml build --no-cache backend &>/dev/null

echo "   Starting services..."
docker-compose -f docker-compose.simple.yml up -d &>/dev/null

echo "   Waiting 10 seconds..."
sleep 10

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ✅ VERIFICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "✅ Checking..."

# Backend check
if curl -s http://localhost:8000/api/v1/health/ &>/dev/null; then
    echo "✅ Backend OK"
    BACKEND_OK=true
else
    echo "❌ Backend failed"
    docker-compose -f docker-compose.simple.yml logs backend | tail -5
    BACKEND_OK=false
fi

# Frontend check
if curl -s http://localhost/ &>/dev/null && [ -f "frontend/dist/index.html" ]; then
    echo "✅ Frontend OK"
    FRONTEND_OK=true
else
    echo "❌ Frontend issue"
    FRONTEND_OK=false
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE"
echo "====================="

if [ "$BACKEND_OK" = true ] && [ "$FRONTEND_OK" = true ]; then
    echo "🌟 FULL SUCCESS!"
    echo "   Frontend: http://$SERVER_IP/"
    echo "   Admin: http://$SERVER_IP:8000/admin (admin/admin123)"
elif [ "$BACKEND_OK" = true ]; then
    echo "⚠️ BACKEND SUCCESS"
    echo "   Admin: http://$SERVER_IP:8000/admin (admin/admin123)"
else
    echo "❌ FAILED"
    echo "   Logs: docker-compose -f docker-compose.simple.yml logs"
fi

echo ""
echo "📊 Final disk: $(df -h . | tail -1 | awk '{print $4}') free"
echo "⚡ Ultra deploy done in ~2 minutes!"