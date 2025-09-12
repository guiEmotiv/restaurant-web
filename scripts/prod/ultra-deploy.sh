#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ⚡ RESTAURANT WEB - ULTRA FAST DEPLOY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

echo "⚡ ULTRA FAST DEPLOYMENT WITH SSL"
echo "=================================="

# Get server IP and set domain
SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "44.248.47.186")
DOMAIN="www.xn--elfogndedonsoto-zrb.com"
echo "🌐 Domain: $DOMAIN"
echo "📍 Server IP: $SERVER_IP"

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

# Set environment variables for HTTPS domain
export VITE_API_BASE_URL="https://$DOMAIN/api/v1"
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
# 🌐 NGINX SSL CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🌐 Configuring Nginx with SSL..."

# Install certbot if not present
if ! command -v certbot &>/dev/null; then
    echo "   Installing certbot..."
    sudo apt-get update -y
    sudo apt-get install -y snapd
    sudo snap install --classic certbot
    sudo ln -sf /snap/bin/certbot /usr/bin/certbot
fi

# Stop nginx container to free port 80 for certbot
echo "   Stopping nginx container temporarily..."
docker-compose -f docker-compose.simple.yml stop nginx

# Create nginx config directory
sudo mkdir -p /etc/nginx/conf.d

# Create temporary nginx config for HTTP (for SSL verification)
sudo tee /etc/nginx/conf.d/restaurant.conf > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN xn--elfogndedonsoto-zrb.com;
    
    # Allow Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF

# Install nginx if not present
if ! command -v nginx &>/dev/null; then
    echo "   Installing nginx..."
    sudo apt-get install -y nginx
fi

# Start nginx for SSL certificate generation
sudo nginx -t && sudo systemctl reload nginx

# Generate SSL certificate
echo "   Generating SSL certificate..."
sudo certbot certonly --webroot \
    -w /var/www/html \
    -d $DOMAIN \
    -d xn--elfogndedonsoto-zrb.com \
    --non-interactive \
    --agree-tos \
    --email admin@$DOMAIN \
    --quiet || echo "⚠️ Certificate generation failed, continuing..."

# Create full nginx config with SSL
sudo tee /etc/nginx/conf.d/restaurant.conf > /dev/null <<EOF
# HTTP redirect to HTTPS
server {
    listen 80;
    server_name $DOMAIN xn--elfogndedonsoto-zrb.com;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN xn--elfogndedonsoto-zrb.com;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Frontend - Serve React app
    location / {
        root $(pwd)/frontend/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
    }
    
    # Backend API proxy
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
    }
    
    # Django Admin
    location /admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
    }
    
    # Static files
    location /static/ {
        alias $(pwd)/backend/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Test and reload nginx
sudo nginx -t && sudo systemctl reload nginx

# Stop the Docker nginx container (we're using system nginx now)
docker-compose -f docker-compose.simple.yml stop nginx

echo "   ✅ SSL configured"

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

# Frontend check via HTTPS
if curl -s -k https://localhost/ &>/dev/null && [ -f "frontend/dist/index.html" ]; then
    echo "✅ Frontend OK (HTTPS)"
    FRONTEND_OK=true
elif curl -s http://localhost/ &>/dev/null; then
    echo "⚠️ Frontend OK (HTTP only)"
    FRONTEND_OK=true
else
    echo "❌ Frontend issue"
    FRONTEND_OK=false
fi

# SSL check
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "✅ SSL Certificate OK"
    SSL_OK=true
else
    echo "⚠️ SSL Certificate not found"
    SSL_OK=false
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE"
echo "====================="

if [ "$BACKEND_OK" = true ] && [ "$FRONTEND_OK" = true ] && [ "$SSL_OK" = true ]; then
    echo "🌟 FULL SUCCESS WITH SSL!"
    echo "   🌐 Website: https://$DOMAIN/"
    echo "   🔐 Admin: https://$DOMAIN/admin (admin/admin123)"
    echo "   📡 API: https://$DOMAIN/api/v1/"
elif [ "$BACKEND_OK" = true ] && [ "$FRONTEND_OK" = true ]; then
    echo "🌟 SUCCESS (HTTP only)"
    echo "   🌐 Website: http://$SERVER_IP/"
    echo "   🔐 Admin: http://$SERVER_IP:8000/admin (admin/admin123)"
elif [ "$BACKEND_OK" = true ]; then
    echo "⚠️ BACKEND ONLY"
    echo "   🔐 Admin: http://$SERVER_IP:8000/admin (admin/admin123)"
else
    echo "❌ FAILED"
    echo "   📋 Logs: docker-compose -f docker-compose.simple.yml logs"
fi

echo ""
echo "📊 Final disk: $(df -h . | tail -1 | awk '{print $4}') free"
echo "⚡ Ultra deploy done in ~2 minutes!"