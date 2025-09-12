#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🚀 RESTAURANT WEB - ULTRA SIMPLE DEPLOY (NO DOCKER)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

echo "🚀 ULTRA SIMPLE DEPLOYMENT"
echo "=========================="
echo "📁 Project: $(pwd)"
echo ""

# Get server IP
SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "44.248.47.186")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🧹 CLEANUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🧹 Cleanup..."
sudo systemctl stop nginx || true
sudo pkill -f "python manage.py runserver" || true
sudo pkill -f "npm run" || true
docker-compose down || true
sudo rm -rf frontend/node_modules frontend/dist || true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 📦 INSTALL MINIMAL TOOLS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📦 Installing tools..."

# Node.js
if ! command -v node &>/dev/null; then
    echo "   Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Python3 venv
if ! python3 -c "import venv" &>/dev/null; then
    echo "   Installing Python venv..."
    sudo apt-get update
    sudo apt-get install -y python3-venv python3-pip
fi

# Nginx
if ! command -v nginx &>/dev/null; then
    echo "   Installing Nginx..."
    sudo apt-get install -y nginx
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🏗️ BUILD FRONTEND
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🏗️ Building frontend..."
cd frontend

echo "   Installing dependencies..."
NODE_OPTIONS='--max-old-space-size=512' npm install --prefer-offline

# Set environment variables
export VITE_API_BASE_URL="http://$SERVER_IP:8000/api/v1"
export VITE_AWS_REGION="us-west-2"
export VITE_AWS_COGNITO_USER_POOL_ID="us-west-2_bdCwF60ZI"
export VITE_AWS_COGNITO_APP_CLIENT_ID="4i9hrd7srgbqbtun09p43ncfn0"
export VITE_NODE_ENV="production"

echo "   Building..."
NODE_OPTIONS='--max-old-space-size=512' npm run build

if [ -f "dist/index.html" ]; then
    echo "   ✅ Frontend built"
else
    echo "   ❌ Frontend build failed"
    exit 1
fi

cd ..

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🐍 SETUP BACKEND
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🐍 Setting up backend..."
cd backend

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "   Creating virtual environment..."
    python3 -m venv venv
fi

echo "   Activating virtual environment..."
source venv/bin/activate

echo "   Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "   Running migrations..."
python manage.py migrate --noinput

echo "   Creating admin user..."
python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@restaurant.com', 'admin123')
    print('Admin user created')
else:
    print('Admin user exists')
" || true

echo "   Collecting static files..."
python manage.py collectstatic --noinput

cd ..

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🌐 CONFIGURE NGINX
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🌐 Configuring Nginx..."

# Create nginx config
sudo tee /etc/nginx/sites-available/restaurant-web > /dev/null <<EOF
server {
    listen 80;
    server_name $SERVER_IP;
    
    # Frontend
    location / {
        root $(pwd)/frontend/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Django Admin
    location /admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Static files
    location /static/ {
        alias $(pwd)/backend/staticfiles/;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/restaurant-web /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx
sudo systemctl enable nginx

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🚀 START SERVICES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🚀 Starting Django backend..."

# Create systemd service for Django
sudo tee /etc/systemd/system/restaurant-backend.service > /dev/null <<EOF
[Unit]
Description=Restaurant Backend
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$(pwd)/backend
Environment=PATH=$(pwd)/backend/venv/bin
ExecStart=$(pwd)/backend/venv/bin/python manage.py runserver 0.0.0.0:8000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Start services
sudo systemctl daemon-reload
sudo systemctl enable restaurant-backend
sudo systemctl start restaurant-backend

# Wait a moment
sleep 5

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ✅ VERIFICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "✅ Checking services..."

# Check backend
if curl -s http://localhost:8000/api/v1/health/ >/dev/null 2>&1; then
    echo "✅ Backend OK"
    BACKEND_OK=true
else
    echo "❌ Backend failed"
    BACKEND_OK=false
fi

# Check frontend through nginx
if curl -s http://localhost/ >/dev/null 2>&1; then
    echo "✅ Frontend OK"
    FRONTEND_OK=true
else
    echo "❌ Frontend failed"
    FRONTEND_OK=false
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================"

if [ "$BACKEND_OK" = true ] && [ "$FRONTEND_OK" = true ]; then
    echo "✅ SUCCESS!"
    echo ""
    echo "🌐 Your app is running at:"
    echo "   Frontend: http://$SERVER_IP"
    echo "   Admin: http://$SERVER_IP/admin (admin/admin123)"
    echo "   API: http://$SERVER_IP/api/v1/"
else
    echo "⚠️ PARTIAL SUCCESS"
    echo ""
    echo "🔧 Check logs:"
    echo "   Backend: sudo systemctl status restaurant-backend"
    echo "   Backend logs: sudo journalctl -u restaurant-backend -f"
    echo "   Nginx: sudo systemctl status nginx"
fi

echo ""
echo "🔧 Management commands:"
echo "   Restart backend: sudo systemctl restart restaurant-backend"
echo "   Restart nginx: sudo systemctl restart nginx"
echo "   View backend logs: sudo journalctl -u restaurant-backend -f"
echo "   Stop all: sudo systemctl stop restaurant-backend nginx"
echo ""
echo "⚡ Simple deploy completed!"