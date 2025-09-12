#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🚀 RESTAURANT WEB - PRODUCTION DEPLOYMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 
# 🎯 PROFESSIONAL DEV → PROD DEPLOYMENT
# 📋 Usage: ./scripts/prod/deploy.sh [--ssl] [--help]
# 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOMAIN="www.xn--elfogndedonsoto-zrb.com"
ALT_DOMAIN="xn--elfogndedonsoto-zrb.com"
SERVER_IP="44.248.47.186"
EMAIL="admin@restaurant.com"
LOG_FILE="/tmp/restaurant-deploy-$(date +%Y%m%d_%H%M%S).log"

# Flags
ENABLE_SSL=false
SHOW_HELP=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions
log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; }
header() { 
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🚀 $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

show_help() {
    cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 RESTAURANT WEB - PRODUCTION DEPLOYMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

USAGE:
  ./scripts/prod/deploy.sh [OPTIONS]

OPTIONS:
  --ssl         Enable SSL/HTTPS with Let's Encrypt
  --help        Show this help

EXAMPLES:
  ./scripts/prod/deploy.sh                 # HTTP deployment
  ./scripts/prod/deploy.sh --ssl           # HTTPS deployment

ARCHITECTURE:
  • Docker containerized backend + frontend
  • Nginx reverse proxy with optimized config
  • Production-ready environment variables
  • Health checks and monitoring
  • Access from your IP: $SERVER_IP

RESULT:
  🌐 Application: http(s)://$DOMAIN
  🔐 Admin Panel: /admin (admin/admin123)
  📊 API: /api/v1/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ssl)
            ENABLE_SSL=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Start deployment
header "RESTAURANT WEB PRODUCTION DEPLOYMENT"

log "📋 Deployment Information:"
log "   Project: $PROJECT_DIR"
log "   Domain: $DOMAIN"
log "   Server IP: $SERVER_IP"
log "   SSL Enabled: $ENABLE_SSL"
log "   Log File: $LOG_FILE"
log ""

cd "$PROJECT_DIR"

# ═══════════════════════════════════════════════════════════════════════════════════════
# 🧹 SYSTEM PREPARATION
# ═══════════════════════════════════════════════════════════════════════════════════════

header "SYSTEM PREPARATION"

log "🧹 Cleaning system resources..."
docker system prune -af &>/dev/null || true
sudo apt-get clean &>/dev/null || true
sudo rm -rf /tmp/* &>/dev/null || true
rm -rf frontend/node_modules frontend/dist &>/dev/null || true
success "System cleaned"

log "🔧 Installing essential tools..."
sudo apt-get update -y &>/dev/null

# Docker
if ! command -v docker &>/dev/null; then
    log "   Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh &>/dev/null
    sudo usermod -aG docker $USER
    success "Docker installed"
else
    log "   Docker already installed: $(docker --version)"
fi

# Docker Compose
if ! command -v docker-compose &>/dev/null; then
    log "   Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose &>/dev/null
    sudo chmod +x /usr/local/bin/docker-compose
    success "Docker Compose installed"
else
    log "   Docker Compose already installed: $(docker-compose --version)"
fi

# Node.js (for local builds)
if ! command -v node &>/dev/null; then
    log "   Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - &>/dev/null
    sudo apt-get install -y nodejs &>/dev/null
    success "Node.js installed: $(node --version)"
else
    log "   Node.js already installed: $(node --version)"
fi

# Nginx
if ! command -v nginx &>/dev/null; then
    log "   Installing Nginx..."
    sudo apt-get install -y nginx &>/dev/null
    sudo systemctl enable nginx
    # Fix nginx log directories
    sudo mkdir -p /var/log/nginx
    sudo touch /var/log/nginx/access.log /var/log/nginx/error.log
    sudo chown -R www-data:adm /var/log/nginx
    success "Nginx installed and configured"
else
    log "   Nginx already installed"
    # Ensure nginx directories exist
    sudo mkdir -p /var/log/nginx
    sudo touch /var/log/nginx/access.log /var/log/nginx/error.log
    sudo chown -R www-data:adm /var/log/nginx
fi

# ═══════════════════════════════════════════════════════════════════════════════════════
# 🏗️ BUILD APPLICATION
# ═══════════════════════════════════════════════════════════════════════════════════════

header "BUILDING APPLICATION"

log "📦 Creating project directories..."
mkdir -p data logs
sudo chown -R $USER:$USER data logs

log "🏗️  Building Docker containers..."
docker-compose -f docker-compose.production.yml build

log "🗄️  Setting up database..."
docker-compose -f docker-compose.production.yml run --rm restaurant-web-backend python manage.py migrate

log "👤 Creating admin user..."
docker-compose -f docker-compose.production.yml run --rm \
    -e DJANGO_SUPERUSER_USERNAME=admin \
    -e DJANGO_SUPERUSER_EMAIL=admin@restaurant.com \
    -e DJANGO_SUPERUSER_PASSWORD=admin123 \
    restaurant-web-backend python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@restaurant.com', 'admin123')
    print('✅ Admin user created')
else:
    print('ℹ️  Admin user already exists')
" &>/dev/null

log "📦 Collecting static files..."
docker-compose -f docker-compose.production.yml run --rm restaurant-web-backend python manage.py collectstatic --noinput &>/dev/null

success "Application built successfully"

# ═══════════════════════════════════════════════════════════════════════════════════════
# 🌐 NGINX CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════════════

header "CONFIGURING WEB SERVER"

CURRENT_DIR=$(pwd)

if [ "$ENABLE_SSL" = true ]; then
    log "🔒 Setting up SSL with Let's Encrypt..."
    
    # Install certbot
    sudo apt-get install -y certbot python3-certbot-nginx &>/dev/null
    
    # Check DNS
    CURRENT_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null)
    DOMAIN_IP=$(dig +short $DOMAIN 2>/dev/null | tail -n1)
    
    log "   Server IP: $CURRENT_IP"
    log "   Domain IP: $DOMAIN_IP"
    
    if [ "$DOMAIN_IP" != "$CURRENT_IP" ]; then
        warning "DNS doesn't point to this server"
        warning "Configure your DNS: A $DOMAIN → $CURRENT_IP"
        warning "Configure your DNS: A $ALT_DOMAIN → $CURRENT_IP"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Deployment aborted"
            exit 1
        fi
    fi
    
    # Temporary nginx for SSL validation
    sudo tee /etc/nginx/sites-available/restaurant-temp >/dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN $ALT_DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 200 'SSL setup in progress...';
        add_header Content-Type text/plain;
    }
}
EOF
    
    sudo mkdir -p /var/www/certbot
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo ln -sf /etc/nginx/sites-available/restaurant-temp /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl restart nginx
    
    # Get SSL certificate
    if sudo certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        --domains $DOMAIN,$ALT_DOMAIN \
        --non-interactive; then
        success "SSL certificates obtained"
        
        # HTTPS Configuration
        sudo tee /etc/nginx/sites-available/restaurant >/dev/null << EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN $ALT_DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN $ALT_DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$ALT_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$ALT_DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;

    # API routes
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /static/ { proxy_pass http://127.0.0.1:8000; }
    location /media/ { proxy_pass http://127.0.0.1:8000; }

    # Frontend files (served directly by nginx)
    root $CURRENT_DIR/frontend/dist;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
        
        # Setup auto-renewal
        (sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && /usr/bin/systemctl reload nginx") | sudo crontab -
        
        success "HTTPS configuration complete"
    else
        warning "SSL setup failed, using HTTP"
        ENABLE_SSL=false
    fi
fi

if [ "$ENABLE_SSL" = false ]; then
    log "🌐 Setting up HTTP configuration..."
    
    # HTTP Configuration
    sudo tee /etc/nginx/sites-available/restaurant >/dev/null << EOF
server {
    listen 80 default_server;
    server_name $DOMAIN $ALT_DOMAIN $SERVER_IP;

    # API routes
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    location /admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
    }
    
    location /static/ { proxy_pass http://127.0.0.1:8000; }
    location /media/ { proxy_pass http://127.0.0.1:8000; }

    # Frontend files (served directly by nginx)
    root $CURRENT_DIR/frontend/dist;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
    
    success "HTTP configuration complete"
fi

sudo rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/restaurant-temp
sudo ln -sf /etc/nginx/sites-available/restaurant /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# ═══════════════════════════════════════════════════════════════════════════════════════
# 🚀 START SERVICES
# ═══════════════════════════════════════════════════════════════════════════════════════

header "STARTING PRODUCTION SERVICES"

log "🛑 Stopping previous containers..."
docker-compose -f docker-compose.production.yml down &>/dev/null || true

log "🚀 Starting production services..."
docker-compose -f docker-compose.production.yml up -d

log "⏳ Waiting for services to start..."
sleep 15

# ═══════════════════════════════════════════════════════════════════════════════════════
# ✅ VERIFICATION & RESULTS
# ═══════════════════════════════════════════════════════════════════════════════════════

header "DEPLOYMENT VERIFICATION"

# Check backend
if curl -s http://localhost:8000/api/v1/health/ >/dev/null 2>&1; then
    success "Backend is running"
    BACKEND_OK=true
else
    error "Backend is not responding"
    BACKEND_OK=false
fi

# Check frontend
PROTOCOL=$([ "$ENABLE_SSL" = true ] && echo "https" || echo "http")
if curl -s $PROTOCOL://localhost/ >/dev/null 2>&1; then
    success "Frontend is running"
    FRONTEND_OK=true
else
    error "Frontend is not responding"
    FRONTEND_OK=false
fi

# Results
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🎉 DEPLOYMENT COMPLETE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ "$BACKEND_OK" = true ] && [ "$FRONTEND_OK" = true ]; then
    success "🎯 ALL SERVICES RUNNING SUCCESSFULLY!"
    echo ""
    echo -e "${GREEN}🌐 ACCESS YOUR APPLICATION:${NC}"
    echo "   Primary: $PROTOCOL://$DOMAIN"
    echo "   Alternative: $PROTOCOL://$ALT_DOMAIN"
    echo "   Direct IP: $PROTOCOL://$SERVER_IP"
    echo ""
    echo -e "${GREEN}🔐 ADMIN PANEL:${NC}"
    echo "   URL: $PROTOCOL://$DOMAIN/admin"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo ""
    echo -e "${GREEN}📊 MONITORING:${NC}"
    echo "   Container status: docker-compose -f docker-compose.production.yml ps"
    echo "   Application logs: docker-compose -f docker-compose.production.yml logs -f"
    echo "   Deployment log: $LOG_FILE"
    echo ""
    if [ "$ENABLE_SSL" = true ]; then
        echo -e "${GREEN}🔒 SSL INFORMATION:${NC}"
        echo "   Certificate auto-renewal: Enabled"
        echo "   Certificate status: sudo certbot certificates"
    fi
else
    warning "DEPLOYMENT PARTIALLY SUCCESSFUL"
    echo ""
    echo -e "${YELLOW}🔧 TROUBLESHOOTING:${NC}"
    if [ "$BACKEND_OK" = false ]; then
        echo "   Backend logs: docker-compose -f docker-compose.production.yml logs restaurant-web-backend"
    fi
    if [ "$FRONTEND_OK" = false ]; then
        echo "   Nginx status: sudo systemctl status nginx"
        echo "   Nginx logs: sudo tail -20 /var/log/nginx/error.log"
    fi
    echo "   Full deployment log: $LOG_FILE"
fi

echo ""
echo -e "${BLUE}📊 System Status:${NC}"
echo "   Disk usage: $(df -h . | tail -1 | awk '{print $5}') of $(df -h . | tail -1 | awk '{print $2}')"
echo "   Docker containers: $(docker ps | wc -l | tr -d ' ') running"
echo ""
success "Professional deployment completed!"