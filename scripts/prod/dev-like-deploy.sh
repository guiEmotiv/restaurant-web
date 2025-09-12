#!/bin/bash
set -e

echo "🔥 DEV-LIKE DEPLOY (Keep React 19, just build faster)"
echo "===================================================="

cd /opt/restaurant-web/frontend

echo "📋 Using same setup as development that works..."

# Set environment (same as ultra-deploy)
export VITE_API_BASE_URL="https://www.xn--elfogndedonsoto-zrb.com/api/v1"
export VITE_AWS_REGION="us-west-2"
export VITE_AWS_COGNITO_USER_POOL_ID="us-west-2_bdCwF60ZI"
export VITE_AWS_COGNITO_APP_CLIENT_ID="4i9hrd7srgbqbtun09p43ncfn0"

echo "✅ Environment set for production build"

# Check if node_modules exists and is recent
if [ -d "node_modules" ] && [ -n "$(find node_modules -maxdepth 0 -mtime -1 2>/dev/null)" ]; then
    echo "🚀 Using existing node_modules (less than 1 day old)"
    echo "   This avoids the slow npm install that hangs"
else
    echo "📦 Need to install dependencies..."
    echo "   This might take a while due to React 19 warnings (but they're harmless)"
    
    # Use the exact same approach as your local dev, but with timeout
    rm -rf node_modules package-lock.json &>/dev/null || true
    
    # Make npm less verbose to avoid the warning spam
    export NPM_CONFIG_LOGLEVEL=error
    export NPM_CONFIG_PROGRESS=false
    export NPM_CONFIG_FUND=false
    export NPM_CONFIG_AUDIT=false
    
    # Install with timeout (warnings are OK, hanging is not)
    echo "   Installing with 5-minute timeout..."
    if timeout 300 NODE_OPTIONS='--max-old-space-size=512' npm install --legacy-peer-deps 2>/dev/null; then
        echo "   ✅ npm install completed"
    else
        echo "   ⚠️ npm install timed out, trying minimal install..."
        NODE_OPTIONS='--max-old-space-size=512' npm install --legacy-peer-deps --production=false --silent
    fi
fi

# Build (same as dev)
echo "🏗️ Building for production..."
rm -rf dist &>/dev/null || true

if NODE_OPTIONS='--max-old-space-size=512' npm run build; then
    echo "✅ Build successful!"
    echo "📊 Build size: $(du -sh dist 2>/dev/null || echo 'unknown')"
    echo "📁 Files created: $(find dist -type f | wc -l) files"
else
    echo "❌ Build failed!"
    echo "🔍 Checking for common issues..."
    
    # Debug info
    echo "   Node version: $(node --version)"
    echo "   NPM version: $(npm --version)"
    echo "   Available memory: $(free -h | head -2)"
    echo "   Package.json React version: $(grep '"react"' package.json || echo 'not found')"
    
    exit 1
fi

# Verify the build worked
if [ -f "dist/index.html" ]; then
    echo "✅ Frontend dist/index.html exists"
    echo "🔍 Checking built files contain correct API URL..."
    if grep -r "xn--elfogndedonsoto-zrb.com" dist/ &>/dev/null; then
        echo "✅ Production domain found in build"
    else
        echo "⚠️ Domain not found in build, checking for any API references..."
        grep -r "api/v1" dist/ | head -2 || echo "   No API URLs found"
    fi
else
    echo "❌ dist/index.html not found after build"
    ls -la dist/ 2>/dev/null || echo "   dist directory missing"
    exit 1
fi

echo ""
echo "🎉 DEV-LIKE DEPLOY READY!"
echo "=========================="
echo "✅ React 19 kept (same as dev)"
echo "✅ Frontend built successfully"
echo "📂 Ready for container deployment"
echo ""
echo "💡 Next step: Start containers with:"
echo "   docker-compose -f docker-compose.production.yml up -d --build"