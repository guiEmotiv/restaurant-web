#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🚀 RESTAURANT WEB - SIMPLE DOCKER DEPLOY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

echo "🚀 SIMPLE DOCKER DEPLOYMENT"
echo "==========================="
echo "📁 Project: $(pwd)"
echo ""

# Get server IP
SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "44.248.47.186")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🧹 DEEP CLEANUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🧹 DEEP CLEANUP..."

# Stop all containers
echo "   Stopping all containers..."
docker stop $(docker ps -aq) 2>/dev/null || true

# Remove all containers
echo "   Removing all containers..."
docker rm $(docker ps -aq) 2>/dev/null || true

# Remove all images
echo "   Removing all images..."
docker rmi $(docker images -q) 2>/dev/null || true

# Remove all volumes
echo "   Removing all volumes..."
docker volume rm $(docker volume ls -q) 2>/dev/null || true

# Remove all networks (except default ones)
echo "   Cleaning networks..."
docker network prune -f 2>/dev/null || true

# Complete Docker cleanup
echo "   Complete Docker system cleanup..."
docker system prune -af --volumes 2>/dev/null || true

# Clean local files
echo "   Cleaning local files..."
rm -rf frontend/node_modules frontend/dist 2>/dev/null || true
rm -rf backend/venv backend/__pycache__ 2>/dev/null || true
rm -rf data/* logs/* 2>/dev/null || true

# Clear system cache
echo "   Clearing system cache..."
sudo apt-get clean 2>/dev/null || true
sudo rm -rf /var/cache/apt/* 2>/dev/null || true
sudo rm -rf /tmp/* 2>/dev/null || true

# Memory cleanup
echo "   Clearing memory cache..."
sudo sync && sudo echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true

echo "   ✅ Cleanup completed"

# Show disk space
echo "📊 Available disk space:"
df -h . | tail -1

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 📦 INSTALL ESSENTIAL TOOLS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📦 Ensuring tools..."

# Docker
if ! command -v docker &>/dev/null; then
    echo "   Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
fi

# Docker Compose
if ! command -v docker-compose &>/dev/null; then
    echo "   Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

echo "   ✅ Tools ready"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🏗️ BUILD AND DEPLOY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🏗️ Building and deploying..."

# Set environment variables for build
export VITE_API_BASE_URL="http://$SERVER_IP:8000/api/v1"
export VITE_AWS_REGION="us-west-2" 
export VITE_AWS_COGNITO_USER_POOL_ID="us-west-2_bdCwF60ZI"
export VITE_AWS_COGNITO_APP_CLIENT_ID="4i9hrd7srgbqbtun09p43ncfn0"

# Create necessary directories
mkdir -p data logs

echo "   Building containers (this may take 2-3 minutes)..."
docker-compose -f docker-compose.simple.yml build --no-cache

echo "   Starting services..."
docker-compose -f docker-compose.simple.yml up -d

echo "   Waiting for services to start..."
sleep 15

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ✅ VERIFICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "✅ Checking deployment..."

# Container status
echo "📊 Container status:"
docker-compose -f docker-compose.simple.yml ps

echo ""

# Check backend
if curl -s http://localhost:8000/api/v1/health/ >/dev/null 2>&1; then
    echo "✅ Backend is running"
    BACKEND_OK=true
else
    echo "❌ Backend not responding"
    echo "Backend logs:"
    docker-compose -f docker-compose.simple.yml logs backend | tail -10
    BACKEND_OK=false
fi

# Check frontend via nginx
if curl -s http://localhost/ >/dev/null 2>&1; then
    echo "✅ Frontend is running"
    FRONTEND_OK=true
else
    echo "❌ Frontend not responding"
    echo "Nginx logs:"
    docker-compose -f docker-compose.simple.yml logs nginx | tail -10
    FRONTEND_OK=false
fi

echo ""
echo "🎉 DEPLOYMENT SUMMARY"
echo "===================="

if [ "$BACKEND_OK" = true ] && [ "$FRONTEND_OK" = true ]; then
    echo "🌟 SUCCESS! Your app is fully deployed!"
    echo ""
    echo "🌐 Access URLs:"
    echo "   Frontend: http://$SERVER_IP/"
    echo "   Admin Panel: http://$SERVER_IP:8000/admin"
    echo "   API: http://$SERVER_IP:8000/api/v1/"
    echo ""
    echo "🔐 Login credentials:"
    echo "   Username: admin"
    echo "   Password: admin123"
    
elif [ "$BACKEND_OK" = true ]; then
    echo "⚠️ PARTIAL SUCCESS - Backend only"
    echo "   Backend: http://$SERVER_IP:8000/admin"
    
else
    echo "❌ DEPLOYMENT FAILED"
    echo "📋 View full logs: docker-compose -f docker-compose.simple.yml logs"
fi

echo ""
echo "🛠️ Management commands:"
echo "   View logs: docker-compose -f docker-compose.simple.yml logs -f"
echo "   Restart: docker-compose -f docker-compose.simple.yml restart"
echo "   Stop: docker-compose -f docker-compose.simple.yml down"
echo "   Status: docker-compose -f docker-compose.simple.yml ps"

echo ""
echo "📊 Final disk usage:"
df -h . | tail -1

echo ""
echo "⚡ Simple Docker deployment completed!"