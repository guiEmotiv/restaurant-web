#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ⚡ RESTAURANT WEB - QUICK DEPLOY (DEV → PROD) WITH FRONTEND
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

echo "⚡ QUICK DEPLOYMENT - DEV TO PROD"
echo "================================="
echo "📁 Project: $(pwd)"
echo ""

# Get server IP for API URL
SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "44.248.47.186")

# Quick system prep
echo "🧹 Quick cleanup..."
docker system prune -f &>/dev/null || true
rm -rf frontend/node_modules frontend/dist &>/dev/null || true

# Essential tools only
echo "🔧 Ensuring Docker is available..."
if ! command -v docker &>/dev/null; then
    echo "   Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh &>/dev/null
    sudo usermod -aG docker $USER
fi

if ! command -v docker-compose &>/dev/null; then
    echo "   Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose &>/dev/null
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Install Node.js if needed for frontend build
if ! command -v node &>/dev/null; then
    echo "   Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - &>/dev/null
    sudo apt-get install -y nodejs &>/dev/null
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🏗️ BUILD FRONTEND
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🏗️  Building frontend..."
cd frontend

# Install dependencies
echo "   📦 Installing dependencies..."
npm install --quiet &>/dev/null

# Set production environment variables
export VITE_API_BASE_URL="http://$SERVER_IP:8000/api/v1"
export VITE_AWS_REGION="us-west-2"
export VITE_AWS_COGNITO_USER_POOL_ID="us-west-2_bdCwF60ZI"
export VITE_AWS_COGNITO_APP_CLIENT_ID="4i9hrd7srgbqbtun09p43ncfn0"
export VITE_NODE_ENV="production"

# Build frontend
echo "   🏗️  Creating production build..."
npm run build &>/dev/null

if [ -f "dist/index.html" ]; then
    echo "   ✅ Frontend built successfully"
else
    echo "   ❌ Frontend build failed"
    exit 1
fi

cd ..

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🐳 BUILD AND START SERVICES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🏗️  Building Docker containers..."
mkdir -p data logs
docker-compose -f docker-compose.production.yml build &>/dev/null

echo "🗄️  Database setup..."
docker-compose -f docker-compose.production.yml run --rm restaurant-web-backend python manage.py migrate &>/dev/null

echo "👤 Creating admin user..."
docker-compose -f docker-compose.production.yml run --rm \
    -e DJANGO_SUPERUSER_USERNAME=admin \
    -e DJANGO_SUPERUSER_EMAIL=admin@restaurant.com \
    -e DJANGO_SUPERUSER_PASSWORD=admin123 \
    restaurant-web-backend python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@restaurant.com', 'admin123')
" &>/dev/null

echo "📦 Collecting static files..."
docker-compose -f docker-compose.production.yml run --rm restaurant-web-backend python manage.py collectstatic --noinput &>/dev/null

echo "🚀 Starting services..."
docker-compose -f docker-compose.production.yml down &>/dev/null || true
docker-compose -f docker-compose.production.yml up -d

echo "⏳ Waiting for services..."
sleep 10

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ✅ VERIFICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check backend
if curl -s http://localhost:8000/api/v1/health/ >/dev/null 2>&1; then
    echo "✅ Backend OK"
    BACKEND_OK=true
else
    echo "❌ Backend failed"
    BACKEND_OK=false
fi

# Check frontend
if curl -s http://localhost/ >/dev/null 2>&1; then
    echo "✅ Frontend OK"
    FRONTEND_OK=true
else
    echo "❌ Frontend failed"
    FRONTEND_OK=false
fi

# Check nginx container
if docker ps | grep nginx >/dev/null 2>&1; then
    echo "✅ Nginx container running"
    NGINX_OK=true
else
    echo "❌ Nginx container not running"
    NGINX_OK=false
fi

echo ""
echo "🎉 QUICK DEPLOYMENT COMPLETE"
echo "============================"

if [ "$BACKEND_OK" = true ] && [ "$FRONTEND_OK" = true ] && [ "$NGINX_OK" = true ]; then
    echo "✅ FULL SUCCESS!"
    echo ""
    echo "🌐 Access your complete app:"
    echo "   Frontend: http://$SERVER_IP"
    echo "   Admin: http://$SERVER_IP/admin (admin/admin123)"
    echo "   API: http://$SERVER_IP/api/v1/"
    echo ""
    echo "📊 Direct backend access:"
    echo "   http://$SERVER_IP:8000/admin"
    echo ""
elif [ "$BACKEND_OK" = true ]; then
    echo "⚠️  PARTIAL SUCCESS (Backend only)"
    echo ""
    echo "🌐 Backend is accessible:"
    echo "   Admin: http://$SERVER_IP:8000/admin (admin/admin123)"
    echo "   API: http://$SERVER_IP:8000/api/v1/"
    echo ""
    echo "🔧 Frontend issues - check logs:"
    echo "   docker-compose -f docker-compose.production.yml logs restaurant-web-nginx"
else
    echo "❌ DEPLOYMENT FAILED"
    echo ""
    echo "🔧 Check logs for details:"
    echo "   docker-compose -f docker-compose.production.yml logs"
fi

echo ""
echo "📊 Monitor:"
echo "   docker-compose -f docker-compose.production.yml ps"
echo "   docker-compose -f docker-compose.production.yml logs -f"
echo ""
echo "⚡ Quick deploy completed in ~3 minutes!"