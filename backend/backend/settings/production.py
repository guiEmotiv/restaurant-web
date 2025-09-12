"""
EC2 Production Settings for Restaurant Management System
Simplified configuration without authentication
"""
import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

# Environment variables are loaded by Docker Compose via env_file
# We don't need to manually load .env.ec2 since Docker handles it
print("ℹ️  Using environment variables loaded by Docker Compose")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECURITY SETTINGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'sc0b)i_r+hlfgo^4v0^1lwvg-y=ttt#$(ngxgr7gh_n=xo5(kz')
DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', '44.248.47.186,xn--elfogndedonsoto-zrb.com,www.xn--elfogndedonsoto-zrb.com,localhost,127.0.0.1').split(',')

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# APPLICATIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSTALLED_APPS = [
    # Core Django
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    
    # Third party
    'rest_framework',
    'corsheaders',  # Re-enabled for better CORS handling
    'drf_spectacular',
    
    # Restaurant Apps
    'config',
    'inventory',
    'operation',
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MIDDLEWARE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',  # Re-enabled for better CORS handling
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
]

# Conditionally add CSRF and Auth middleware based on authentication mode
if os.getenv('USE_COGNITO_AUTH', 'False').lower() == 'true':
    # For Cognito auth, add CSRF exemption for API endpoints
    MIDDLEWARE.extend([
        'backend.csrf_exempt_middleware.CSRFExemptAPIMiddleware',  # Exempt API from CSRF
        'django.middleware.csrf.CsrfViewMiddleware',  # Still needed for admin/web
        'django.contrib.auth.middleware.AuthenticationMiddleware',  # Required by DRF
        'backend.cognito_auth.CognitoAuthenticationMiddleware',  # AWS Cognito authentication
    ])
else:
    # For non-auth mode, keep standard CSRF and auth
    MIDDLEWARE.extend([
        'django.middleware.csrf.CsrfViewMiddleware',
        'django.contrib.auth.middleware.AuthenticationMiddleware',
    ])

# Always add these at the end
MIDDLEWARE.extend([
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
])

ROOT_URLCONF = 'backend.urls'
WSGI_APPLICATION = 'backend.wsgi.application'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DATABASE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Configuración de base de datos centralizada
db_name = os.getenv('DATABASE_NAME', 'restaurant.prod.sqlite3')
db_path = os.getenv('DATABASE_PATH', '/app/data')

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': os.path.join(db_path, db_name),
    }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEMPLATES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTERNATIONALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

LANGUAGE_CODE = 'es-pe'
TIME_ZONE = 'America/Lima'
USE_I18N = True
USE_TZ = True

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATIC FILES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# FRONTEND SERVING - Serve React frontend files
STATICFILES_DIRS = [
    BASE_DIR / 'frontend' / 'dist',  # React build output
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MEDIA FILES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'data' / 'media'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# REST FRAMEWORK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Determine authentication and permission classes based on authentication mode
if os.getenv('USE_COGNITO_AUTH', 'False').lower() == 'true':
    DEFAULT_AUTHENTICATION_CLASSES = ['backend.cognito_drf_auth.CognitoJWTAuthentication']
    DEFAULT_PERMISSION_CLASSES = ['rest_framework.permissions.IsAuthenticated']
else:
    DEFAULT_AUTHENTICATION_CLASSES = ['rest_framework.authentication.SessionAuthentication']
    DEFAULT_PERMISSION_CLASSES = ['rest_framework.permissions.AllowAny']

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': DEFAULT_AUTHENTICATION_CLASSES,
    'DEFAULT_PERMISSION_CLASSES': DEFAULT_PERMISSION_CLASSES,
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 100,  # Aumentado para mostrar más elementos
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CORS SETTINGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# CORS Configuration - Allow all origins in development/production
CORS_ALLOWED_ORIGINS = [
    "https://www.xn--elfogndedonsoto-zrb.com",
    "https://xn--elfogndedonsoto-zrb.com",
    "http://www.xn--elfogndedonsoto-zrb.com",
    "http://xn--elfogndedonsoto-zrb.com",
    "http://localhost:5173",  # Vite dev server
    "http://127.0.0.1:5173",
    "http://44.248.47.186",  # EC2 production IP
    "https://44.248.47.186", # EC2 production IP with SSL
]

# Allow all origins for easier deployment (can be restricted later)
CORS_ALLOW_ALL_ORIGINS = True  # Allow all origins in production for now
CORS_ALLOW_CREDENTIALS = True

# Allow specific headers
CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
    'expires',
    'cache-control',
    'pragma',
]

# Allow specific methods
CORS_ALLOW_METHODS = [
    'DELETE',
    'GET',
    'OPTIONS',
    'PATCH',
    'POST',
    'PUT',
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECURITY SETTINGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Security Headers
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'

# CSRF Settings - disable for API when using JWT authentication
if os.getenv('USE_COGNITO_AUTH', 'False').lower() == 'true':
    # For JWT authentication, we don't need CSRF protection on API endpoints
    CSRF_EXEMPT_URLS = [r'^api/v1/.*$']
    CSRF_COOKIE_SECURE = False  # Allow HTTP for development
    CSRF_COOKIE_HTTPONLY = False
else:
    # Standard CSRF protection for non-JWT authentication
    CSRF_COOKIE_SECURE = not DEBUG
    CSRF_COOKIE_HTTPONLY = True

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOGGING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': BASE_DIR / 'data' / 'logs' / 'django.log',
            'formatter': 'verbose',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console', 'file'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}

# Create logs directory
try:
    os.makedirs(BASE_DIR / 'data' / 'logs', exist_ok=True)
except PermissionError:
    # In case of permission issues, use a fallback directory
    LOGGING['handlers']['file']['filename'] = '/tmp/django.log'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# API DOCUMENTATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SPECTACULAR_SETTINGS = {
    'TITLE': 'Restaurant Management API',
    'DESCRIPTION': 'API completa para la gestión de restaurantes sin autenticación',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AWS COGNITO SETTINGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Authentication Mode
USE_COGNITO_AUTH = os.getenv('USE_COGNITO_AUTH', 'True').lower() == 'true'  # Habilitado por defecto en producción

# AWS Configuration
AWS_DEFAULT_REGION = os.getenv('AWS_DEFAULT_REGION', 'us-west-2')
AWS_REGION = AWS_DEFAULT_REGION

# Cognito Configuration
COGNITO_USER_POOL_ID = os.getenv('COGNITO_USER_POOL_ID', '')
COGNITO_APP_CLIENT_ID = os.getenv('COGNITO_APP_CLIENT_ID', '')

# Set COGNITO_ENABLED for the middleware
COGNITO_ENABLED = USE_COGNITO_AUTH

# Validate required Cognito settings only if authentication is enabled
if USE_COGNITO_AUTH:
    if not COGNITO_USER_POOL_ID:
        print("⚠️  COGNITO_USER_POOL_ID not set. Authentication will fail.")
    if not COGNITO_APP_CLIENT_ID:
        print("⚠️  COGNITO_APP_CLIENT_ID not set. Authentication will fail.")
    print(f"✅ AWS Cognito authentication ENABLED - Pool: {COGNITO_USER_POOL_ID}")
else:
    print("ℹ️  Running without AWS Cognito authentication (USE_COGNITO_AUTH=False)")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OTHER SETTINGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Create data directory
os.makedirs(BASE_DIR / 'data', exist_ok=True)