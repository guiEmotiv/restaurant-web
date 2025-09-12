#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ⚡ RESTAURANT WEB - QUICK DEPLOY (DEV → PROD)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

echo "⚡ QUICK DEPLOYMENT - DEV TO PROD"
echo "================================="
echo "📁 Project: $(pwd)"
echo ""

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

# Build and start
echo "🏗️  Building application..."
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

echo "🚀 Starting services..."
docker-compose -f docker-compose.production.yml down &>/dev/null || true
docker-compose -f docker-compose.production.yml up -d

echo "⏳ Waiting..."
sleep 10

# Quick verification
if curl -s http://localhost:8000/api/v1/health/ >/dev/null 2>&1; then
    echo "✅ Backend OK"
    BACKEND_OK=true
else
    echo "❌ Backend failed"
    BACKEND_OK=false
fi

echo ""
echo "🎉 QUICK DEPLOYMENT COMPLETE"
echo "============================"

if [ "$BACKEND_OK" = true ]; then
    echo "✅ SUCCESS!"
    echo ""
    echo "🌐 Access your app:"
    echo "   http://44.248.47.186:8000/admin (admin/admin123)"
    echo "   http://localhost:8000/api/v1/"
    echo ""
    echo "📊 Monitor:"
    echo "   docker-compose -f docker-compose.production.yml ps"
    echo "   docker-compose -f docker-compose.production.yml logs -f"
else
    echo "⚠️  PARTIAL SUCCESS"
    echo "   Check logs: docker-compose -f docker-compose.production.yml logs"
fi

echo ""
echo "⚡ Quick deploy completed in ~2 minutes!"