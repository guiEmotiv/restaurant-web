#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🔍 RESTAURANT WEB - DEBUG DEPLOYMENT (VERBOSE)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# No exit on error - we want to see all failures
set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[LOG]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "🔍 DEBUG DEPLOYMENT SCRIPT"
echo "=========================="
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 1: SYSTEM INFO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📊 SYSTEM INFORMATION"
echo "===================="
log "Current directory: $(pwd)"
log "Current user: $(whoami)"
log "Server IP: $(curl -s https://ipinfo.io/ip 2>/dev/null || echo 'Cannot detect')"
log "Disk space:"
df -h . | tail -1
log "Memory:"
free -h | grep Mem
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2: CHECK REQUIREMENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🔧 CHECKING REQUIREMENTS"
echo "======================="

# Docker
if command -v docker &>/dev/null; then
    success "Docker installed: $(docker --version)"
else
    error "Docker NOT installed"
fi

# Docker Compose
if command -v docker-compose &>/dev/null; then
    success "Docker Compose installed: $(docker-compose --version)"
else
    error "Docker Compose NOT installed"
fi

# Node.js
if command -v node &>/dev/null; then
    success "Node.js installed: $(node --version)"
else
    warning "Node.js NOT installed (will install if needed)"
fi

# npm
if command -v npm &>/dev/null; then
    success "npm installed: $(npm --version)"
else
    warning "npm NOT installed"
fi

# Check files
echo ""
log "Checking project files:"
if [ -f "docker-compose.production.yml" ]; then
    success "docker-compose.production.yml exists"
else
    error "docker-compose.production.yml NOT found"
fi

if [ -f ".env.production" ]; then
    success ".env.production exists"
else
    error ".env.production NOT found"
fi

if [ -d "frontend" ]; then
    success "frontend directory exists"
    ls -la frontend/ | head -5
else
    error "frontend directory NOT found"
fi

if [ -d "backend" ]; then
    success "backend directory exists"
else
    error "backend directory NOT found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 3: CLEANUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🧹 CLEANUP"
echo "========="
log "Stopping existing containers..."
docker-compose -f docker-compose.production.yml down 2>&1 | head -5

log "Cleaning Docker..."
docker system prune -f 2>&1 | tail -2

log "Removing old frontend build..."
rm -rf frontend/dist frontend/node_modules
if [ $? -eq 0 ]; then
    success "Frontend cleaned"
else
    warning "Frontend cleanup had issues"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 4: FRONTEND BUILD (DETAILED)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🏗️ FRONTEND BUILD"
echo "==============="

# Install Node.js if missing
if ! command -v node &>/dev/null; then
    log "Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    if [ $? -eq 0 ]; then
        success "Node.js installed: $(node --version)"
    else
        error "Node.js installation failed"
        exit 1
    fi
fi

cd frontend

log "Installing npm dependencies..."
npm install 2>&1 | tail -5
if [ $? -eq 0 ]; then
    success "Dependencies installed"
else
    error "npm install failed"
    npm install --verbose
    exit 1
fi

# Set environment variables
SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "44.248.47.186")
export VITE_API_BASE_URL="http://$SERVER_IP:8000/api/v1"
export VITE_AWS_REGION="us-west-2"
export VITE_AWS_COGNITO_USER_POOL_ID="us-west-2_bdCwF60ZI"
export VITE_AWS_COGNITO_APP_CLIENT_ID="4i9hrd7srgbqbtun09p43ncfn0"
export VITE_NODE_ENV="production"

log "Environment variables set:"
echo "   VITE_API_BASE_URL=$VITE_API_BASE_URL"

log "Building frontend..."
npm run build 2>&1 | tail -10
if [ -f "dist/index.html" ]; then
    success "Frontend built successfully"
    log "Frontend dist contents:"
    ls -la dist/ | head -5
else
    error "Frontend build failed - dist/index.html not found"
    log "Trying verbose build:"
    npm run build
    exit 1
fi

cd ..
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 5: DOCKER BUILD
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🐳 DOCKER BUILD"
echo "=============="

log "Building Docker images..."
docker-compose -f docker-compose.production.yml build 2>&1 | tail -10
if [ $? -eq 0 ]; then
    success "Docker images built"
else
    error "Docker build failed"
    log "Trying verbose build:"
    docker-compose -f docker-compose.production.yml build --no-cache
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 6: DATABASE SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🗄️ DATABASE SETUP"
echo "==============="

log "Running migrations..."
docker-compose -f docker-compose.production.yml run --rm restaurant-web-backend python manage.py migrate 2>&1 | tail -5
if [ $? -eq 0 ]; then
    success "Migrations completed"
else
    error "Migrations failed"
fi

log "Creating admin user..."
docker-compose -f docker-compose.production.yml run --rm \
    -e DJANGO_SUPERUSER_USERNAME=admin \
    -e DJANGO_SUPERUSER_EMAIL=admin@restaurant.com \
    -e DJANGO_SUPERUSER_PASSWORD=admin123 \
    restaurant-web-backend python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@restaurant.com', 'admin123')
    print('Admin user created')
else:
    print('Admin user already exists')
" 2>&1

log "Collecting static files..."
docker-compose -f docker-compose.production.yml run --rm restaurant-web-backend python manage.py collectstatic --noinput 2>&1 | tail -3

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 7: START SERVICES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🚀 STARTING SERVICES"
echo "=================="

log "Starting containers..."
docker-compose -f docker-compose.production.yml up -d 2>&1
if [ $? -eq 0 ]; then
    success "Containers started"
else
    error "Container startup failed"
fi

log "Waiting for services to start..."
sleep 10

log "Container status:"
docker-compose -f docker-compose.production.yml ps

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 8: VERIFICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "✅ VERIFICATION"
echo "============="

# Check backend
log "Testing backend..."
if curl -f -s http://localhost:8000/api/v1/health/ >/dev/null 2>&1; then
    success "Backend is running at :8000"
else
    error "Backend NOT responding"
    log "Backend logs:"
    docker-compose -f docker-compose.production.yml logs --tail=10 restaurant-web-backend
fi

# Check nginx/frontend
log "Testing nginx/frontend..."
if curl -f -s http://localhost/ >/dev/null 2>&1; then
    success "Nginx/Frontend is running at :80"
else
    warning "Nginx/Frontend NOT responding at :80"
    log "Nginx logs:"
    docker-compose -f docker-compose.production.yml logs --tail=10 restaurant-web-nginx
fi

# Check port 80 usage
log "Checking port 80:"
sudo lsof -i :80 2>&1 | head -5 || echo "Port 80 is free"

# Check port 8000 usage
log "Checking port 8000:"
sudo lsof -i :8000 2>&1 | head -5 || echo "Port 8000 is free"

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FINAL REPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📊 DEPLOYMENT REPORT"
echo "=================="

SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "44.248.47.186")

echo ""
echo "🌐 ACCESS URLs:"
echo "   Backend Admin: http://$SERVER_IP:8000/admin"
echo "   Backend API: http://$SERVER_IP:8000/api/v1/"
echo "   Frontend (if nginx works): http://$SERVER_IP/"
echo ""
echo "🔐 CREDENTIALS:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "🔧 TROUBLESHOOTING COMMANDS:"
echo "   View all logs: docker-compose -f docker-compose.production.yml logs"
echo "   View backend logs: docker-compose -f docker-compose.production.yml logs restaurant-web-backend"
echo "   View nginx logs: docker-compose -f docker-compose.production.yml logs restaurant-web-nginx"
echo "   Container status: docker-compose -f docker-compose.production.yml ps"
echo "   Stop all: docker-compose -f docker-compose.production.yml down"
echo ""
echo "🔍 DEBUG DEPLOYMENT COMPLETE"