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

# Create nginx config directory and clean conflicting configs
sudo mkdir -p /etc/nginx/conf.d
sudo rm -f /etc/nginx/sites-enabled/restaurant-web 2>/dev/null || true
sudo rm -f /etc/nginx/conf.d/restaurant.conf 2>/dev/null || true

# Create temporary nginx config for HTTP (for SSL verification)
echo "   Creating temporary nginx config for SSL verification..."
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

# Check nginx status and start/reload properly
echo "   Checking nginx status..."
if systemctl is-active --quiet nginx; then
    echo "   Nginx is running, reloading configuration..."
    sudo systemctl reload nginx
else
    echo "   Nginx is stopped, starting nginx..."
    sudo systemctl start nginx
    sudo systemctl enable nginx
fi

echo "   Nginx status: $(systemctl is-active nginx)"

# Create webroot directory for certbot
sudo mkdir -p /var/www/html
sudo chown www-data:www-data /var/www/html

# Generate SSL certificate with verbose output
echo "   Generating SSL certificate..."
echo "   Domain: $DOMAIN"
echo "   Alternative domain: xn--elfogndedonsoto-zrb.com"

if sudo certbot certonly --webroot \
    -w /var/www/html \
    -d $DOMAIN \
    -d xn--elfogndedonsoto-zrb.com \
    --expand \
    --non-interactive \
    --agree-tos \
    --email admin@$DOMAIN; then
    echo "   ✅ SSL certificate generated successfully"
    SSL_CERT_OK=true
else
    echo "   ⚠️ SSL certificate generation failed"
    echo "   Checking if certificates already exist..."
    # Check both possible certificate locations
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo "   ✅ Certificate found at $DOMAIN location"
        SSL_CERT_OK=true
    elif [ -f "/etc/letsencrypt/live/xn--elfogndedonsoto-zrb.com/fullchain.pem" ]; then
        echo "   ✅ Certificate found at xn--elfogndedonsoto-zrb.com location"
        SSL_CERT_OK=true
        # Update DOMAIN for nginx config
        CERT_DOMAIN="xn--elfogndedonsoto-zrb.com"
    else
        echo "   ❌ No certificate found, will continue without SSL"
        SSL_CERT_OK=false
    fi
fi

# Create full nginx config (conditional SSL)
echo "   Creating nginx configuration..."
if [ "$SSL_CERT_OK" = true ]; then
    # Use the correct certificate domain
    CERT_DOMAIN=${CERT_DOMAIN:-$DOMAIN}
    echo "   Using HTTPS configuration with certificate: $CERT_DOMAIN"
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
    ssl_certificate /etc/letsencrypt/live/$CERT_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$CERT_DOMAIN/privkey.pem;
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
    
    # Backend API proxy with detailed logging
    location /api/ {
        # Log all API requests for debugging
        access_log /var/log/nginx/api_access.log;
        error_log /var/log/nginx/api_error.log debug;
        
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        
        # Add debugging headers
        add_header X-Debug-Proxy "backend-https" always;
        add_header X-Backend-Host "127.0.0.1:8000" always;
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
else
    echo "   Using HTTP-only configuration"
    sudo tee /etc/nginx/conf.d/restaurant.conf > /dev/null <<EOF
# HTTP server (no SSL)
server {
    listen 80;
    server_name $DOMAIN xn--elfogndedonsoto-zrb.com $SERVER_IP;
    
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
    
    # Backend API proxy with detailed logging
    location /api/ {
        # Log all API requests for debugging
        access_log /var/log/nginx/api_access.log;
        error_log /var/log/nginx/api_error.log debug;
        
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header X-Forwarded-Host \$host;
        
        # Add debugging headers
        add_header X-Debug-Proxy "backend-http" always;
        add_header X-Backend-Host "127.0.0.1:8000" always;
    }
    
    # Django Admin
    location /admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
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
fi

# Test and reload nginx with detailed output
echo "   Testing nginx configuration..."
if sudo nginx -t; then
    echo "   ✅ Nginx configuration is valid"
    echo "   Reloading nginx..."
    if sudo systemctl reload nginx; then
        echo "   ✅ Nginx reloaded successfully"
    else
        echo "   ⚠️ Nginx reload failed, restarting..."
        sudo systemctl restart nginx
        echo "   Nginx status after restart: $(systemctl is-active nginx)"
    fi
else
    echo "   ❌ Nginx configuration test failed"
    echo "   Configuration file contents:"
    sudo cat /etc/nginx/conf.d/restaurant.conf
fi

# Stop the Docker nginx container (we're using system nginx now)
echo "   Stopping Docker nginx container..."
docker-compose -f docker-compose.simple.yml stop nginx 2>/dev/null || true

if [ "$SSL_CERT_OK" = true ]; then
    echo "   ✅ SSL configured with nginx"
else
    echo "   ✅ HTTP configured with nginx (no SSL)"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ✅ VERIFICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "✅ Detailed verification..."

# Show current services status
echo "   📊 Docker containers:"
docker-compose -f docker-compose.simple.yml ps

echo "   📊 System nginx status:"
systemctl status nginx --no-pager -l

echo "   📊 Port usage:"
sudo netstat -tlnp | grep ":80\|:443\|:8000" || echo "   No processes found on ports 80, 443, 8000"

# Backend check with detailed output
echo "   🔍 Testing backend..."
echo "   Direct backend test (localhost:8000):"
if curl -s http://localhost:8000/api/v1/health/ &>/dev/null; then
    echo "   ✅ Backend responding at localhost:8000"
    echo "   Available endpoints:"
    curl -s http://localhost:8000/api/v1/ | head -5 || echo "   Could not fetch API root"
    BACKEND_OK=true
else
    echo "   ❌ Backend not responding"
    echo "   Backend logs (last 10 lines):"
    docker-compose -f docker-compose.simple.yml logs backend | tail -10
    BACKEND_OK=false
fi

# Test API proxy through nginx
echo "   🔍 Testing API proxy through nginx..."
if [ "$SSL_OK" = true ]; then
    echo "   Testing HTTPS API proxy:"
    curl -s -k -I https://localhost/api/v1/health/ | head -3 || echo "   HTTPS API proxy failed"
    echo "   Testing specific dashboard endpoint:"
    curl -s -k -I https://localhost/api/v1/dashboard/report/ | head -3 || echo "   Dashboard endpoint failed"
else
    echo "   Testing HTTP API proxy:"
    curl -s -I http://localhost/api/v1/health/ | head -3 || echo "   HTTP API proxy failed"
    echo "   Testing specific dashboard endpoint:"
    curl -s -I http://localhost/api/v1/dashboard/report/ | head -3 || echo "   Dashboard endpoint failed"
fi

# Frontend check with detailed output
echo "   🔍 Testing frontend..."
if [ -f "frontend/dist/index.html" ]; then
    echo "   ✅ Frontend files exist"
    if curl -s -k https://localhost/ &>/dev/null; then
        echo "   ✅ Frontend accessible via HTTPS"
        FRONTEND_OK=true
    elif curl -s http://localhost/ &>/dev/null; then
        echo "   ✅ Frontend accessible via HTTP"
        FRONTEND_OK=true
    else
        echo "   ❌ Frontend not accessible"
        echo "   Nginx error log (last 5 lines):"
        sudo tail -5 /var/log/nginx/error.log 2>/dev/null || echo "   No nginx error log found"
        FRONTEND_OK=false
    fi
else
    echo "   ❌ Frontend dist files missing"
    FRONTEND_OK=false
fi

# SSL check with details
echo "   🔍 Checking SSL..."
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "   ✅ SSL Certificate found at $DOMAIN"
    echo "   Certificate expires: $(sudo openssl x509 -enddate -noout -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem 2>/dev/null | cut -d= -f2 || echo 'Unable to read expiry')"
    SSL_OK=true
elif [ -f "/etc/letsencrypt/live/xn--elfogndedonsoto-zrb.com/fullchain.pem" ]; then
    echo "   ✅ SSL Certificate found at xn--elfogndedonsoto-zrb.com"
    echo "   Certificate expires: $(sudo openssl x509 -enddate -noout -in /etc/letsencrypt/live/xn--elfogndedonsoto-zrb.com/fullchain.pem 2>/dev/null | cut -d= -f2 || echo 'Unable to read expiry')"
    SSL_OK=true
else
    echo "   ⚠️ SSL Certificate not found"
    echo "   Let's Encrypt directory contents:"
    sudo ls -la /etc/letsencrypt/live/ 2>/dev/null || echo "   No certificates directory found"
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
echo "📊 DEBUGGING INFORMATION"
echo "======================"
echo "   📋 Nginx API logs (last 5 lines):"
sudo tail -5 /var/log/nginx/api_access.log 2>/dev/null || echo "   No API access logs yet"

echo "   📋 Nginx error logs (last 5 lines):"
sudo tail -5 /var/log/nginx/error.log 2>/dev/null || echo "   No nginx error logs"

echo "   📋 Django logs from container (last 5 lines):"
docker-compose -f docker-compose.simple.yml logs backend | tail -5

echo "   📋 Active nginx configuration:"
sudo nginx -T 2>/dev/null | grep -A 10 -B 5 "location /api/" || echo "   Could not read nginx config"

echo ""
echo "💡 DEBUGGING COMMANDS:"
echo "   View API logs: sudo tail -f /var/log/nginx/api_access.log"
echo "   View nginx errors: sudo tail -f /var/log/nginx/error.log" 
echo "   View backend logs: docker-compose -f docker-compose.simple.yml logs -f backend"
echo "   Test API directly: curl http://localhost:8000/api/v1/health/"
echo "   Test API via nginx: curl -k https://localhost/api/v1/health/"

echo ""
echo "📊 Final disk: $(df -h . | tail -1 | awk '{print $4}') free"
echo "⚡ Ultra deploy done in ~2 minutes!"