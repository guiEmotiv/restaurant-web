#!/bin/bash
set -e

echo "🔧 FIX DEPLOY - Handle React conflicts properly"
echo "==============================================="

cd /opt/restaurant-web/frontend

echo "🔍 Current React version in package.json:"
grep '"react"' package.json || echo "No React found"

echo ""
echo "🛠️ FIXING React version conflicts..."

# Backup original package.json
cp package.json package.json.backup

# Fix React version to 18.x for AWS Amplify compatibility
echo "   Downgrading React to 18.x for AWS Amplify compatibility..."
sed -i 's/"react": ".*"/"react": "^18.2.0"/' package.json
sed -i 's/"react-dom": ".*"/"react-dom": "^18.2.0"/' package.json
sed -i 's/"@types\/react": ".*"/"@types\/react": "^18.2.0"/' package.json
sed -i 's/"@types\/react-dom": ".*"/"@types\/react-dom": "^18.2.0"/' package.json

echo "✅ Fixed React versions in package.json"
grep '"react"' package.json

# Clean everything
echo "🧹 Cleaning node_modules and cache..."
rm -rf node_modules package-lock.json .npm &>/dev/null || true
npm cache clean --force &>/dev/null || true

# Set environment
export VITE_API_BASE_URL="https://www.xn--elfogndedonsoto-zrb.com/api/v1"
export VITE_AWS_REGION="us-west-2"
export VITE_AWS_COGNITO_USER_POOL_ID="us-west-2_bdCwF60ZI"
export VITE_AWS_COGNITO_APP_CLIENT_ID="4i9hrd7srgbqbtun09p43ncfn0"

echo "📦 Installing with fixed React version..."

# Configure npm for speed
npm config set fund false
npm config set audit false
npm config set progress false

# Install with proper React 18
if NODE_OPTIONS='--max-old-space-size=512' npm install --legacy-peer-deps --no-audit --no-fund --silent; then
    echo "✅ npm install successful with React 18"
else
    echo "❌ npm install failed, trying with --force..."
    NODE_OPTIONS='--max-old-space-size=512' npm install --force --no-audit --no-fund --silent
fi

# Verify React version installed
echo "🔍 Installed React version:"
npm list react --depth=0 2>/dev/null || echo "Could not check React version"

# Build
echo "🏗️ Building frontend..."
if NODE_OPTIONS='--max-old-space-size=512' npm run build; then
    echo "✅ Build successful"
    ls -la dist/
else
    echo "❌ Build failed"
    exit 1
fi

# Restore original package.json for version control
mv package.json.backup package.json
echo "📝 Restored original package.json"

echo ""
echo "🎉 FIXED DEPLOY COMPLETE!"
echo "Frontend built with React 18 compatibility"
echo "dist folder created: $(du -sh dist 2>/dev/null)"