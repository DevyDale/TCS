"""Production settings — PostgreSQL, Redis, Cloudinary, hardened security."""
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration
from .base import *

env.read_env(BASE_DIR / ".env")

SECRET_KEY    = env("SECRET_KEY")
DEBUG         = False
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS")

DATABASES = {
    "default": {
        **env.db("DATABASE_URL"),
        "CONN_MAX_AGE": 60,
    }
}

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": env("REDIS_URL"),
    }
}

CELERY_BROKER_URL       = env("CELERY_BROKER_URL")
CELERY_TASK_ALWAYS_EAGER = False

# ── Cloudinary (all media — posts, avatars, covers, arcade) ──────
# S3 is no longer used. Cloudinary handles everything.
# DEFAULT_FILE_STORAGE is already set in base.py.
# Just make sure these three env vars are set in production:
#   CLOUDINARY_CLOUD_NAME
#   CLOUDINARY_API_KEY
#   CLOUDINARY_API_SECRET

# ── Channels ─────────────────────────────────────────────────────
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG":  {"hosts": [env("REDIS_URL")]},
    }
}

# ── CORS ─────────────────────────────────────────────────────────
CORS_ALLOWED_ORIGINS = env.list("CORS_ALLOWED_ORIGINS", default=[])

# ── Security ─────────────────────────────────────────────────────
SECURE_SSL_REDIRECT             = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_HSTS_SECONDS             = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS  = True
SESSION_COOKIE_SECURE           = True
CSRF_COOKIE_SECURE              = True
X_FRAME_OPTIONS                 = "DENY"

# ── Email ────────────────────────────────────────────────────────
EMAIL_BACKEND       = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST          = env("EMAIL_HOST",          default="")
EMAIL_PORT          = env.int("EMAIL_PORT",      default=587)
EMAIL_HOST_USER     = env("EMAIL_HOST_USER",     default="")
EMAIL_HOST_PASSWORD = env("EMAIL_HOST_PASSWORD", default="")
EMAIL_USE_TLS       = True

# ── Firebase ─────────────────────────────────────────────────────
FIREBASE_CREDENTIALS_JSON = env("FIREBASE_CREDENTIALS_JSON", default="")

# ── Sentry ───────────────────────────────────────────────────────
SENTRY_DSN = env("SENTRY_DSN", default="")
if SENTRY_DSN:
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        integrations=[DjangoIntegration()],
        traces_sample_rate=0.2,
    )