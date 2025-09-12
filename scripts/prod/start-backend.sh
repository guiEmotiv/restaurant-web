#!/bin/bash

# Simple backend start script for production
echo "🚀 Starting Django backend in production mode..."

# Navigate to backend directory
cd /app/backend || cd backend || { echo "Backend directory not found"; exit 1; }

# Run migrations
echo "Running migrations..."
python manage.py migrate --noinput

# Collect static files
echo "Collecting static files..."
python manage.py collectstatic --noinput

# Create superuser if doesn't exist
echo "Checking admin user..."
python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@restaurant.com', 'admin123')
    print('Admin user created')
else:
    print('Admin user exists')
"

# Start Django development server (temporary - replace with gunicorn later)
echo "Starting Django server..."
python manage.py runserver 0.0.0.0:8000