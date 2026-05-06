"""Development settings — SQLite, Cloudinary (or local fallback), no Redis required."""
from .base import *

try:
    env.read_env(BASE_DIR / ".env")
except Exception:
    pass

SECRET_KEY    = env("SECRET_KEY", default="dev-secret-key-not-for-production-use-only")
DEBUG         = True
ALLOWED_HOSTS = ["*"]

# ── Database ─────────────────────────────────────────────────────
DATABASES = {
    "default": env.db("DATABASE_URL", default=f"sqlite:///{BASE_DIR / 'db.sqlite3'}")
}

# ── Cache ────────────────────────────────────────────────────────
CACHES = {
    "default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}
}

# ── Celery ───────────────────────────────────────────────────────
CELERY_BROKER_URL       = env("CELERY_BROKER_URL", default="redis://localhost:6379/1")
CELERY_TASK_ALWAYS_EAGER = True

# ── Cloudinary / media ────────────────────────────────────────────
# If CLOUDINARY_CLOUD_NAME is set in .env, images go to Cloudinary.
# If not set (empty string), fall back to local disk storage so you
# can develop without a Cloudinary account.
if CLOUDINARY_STORAGE.get("CLOUD_NAME"):
    DEFAULT_FILE_STORAGE = "cloudinary_storage.storage.MediaCloudinaryStorage"
else:
    DEFAULT_FILE_STORAGE = "django.core.files.storage.FileSystemStorage"
    MEDIA_URL  = "/media/"
    MEDIA_ROOT = BASE_DIR / "media"

# ── CORS ─────────────────────────────────────────────────────────
CORS_ALLOW_ALL_ORIGINS = True

# ── Email ────────────────────────────────────────────────────────
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# ── Channels ─────────────────────────────────────────────────────
CHANNEL_LAYERS = {
    "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
}

FIREBASE_CREDENTIALS_JSON = env("FIREBASE_CREDENTIALS_JSON", default="")