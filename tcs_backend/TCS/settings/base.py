"""
TCS Backend — Base Settings
"""
from pathlib import Path
from datetime import timedelta
import environ

env = environ.Env(DEBUG=(bool, False))

BASE_DIR = Path(__file__).resolve().parent.parent.parent

DJANGO_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
]

THIRD_PARTY_APPS = [
    "channels",
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "corsheaders",
    "django_filters",
    "drf_spectacular",
    "django_cleanup.apps.CleanupConfig",
    "django_celery_results",
    "django_celery_beat",
    "storages",
    "cloudinary",
    "cloudinary_storage",
]

LOCAL_APPS = [
    "apps.ai",
    "apps.accounts",
    "apps.dataentry",
    "apps.posts",
    "apps.chat",
    "apps.groups",
    "apps.arcade",
    "apps.events",
    "apps.notifications",
    "apps.media",
    "apps.feedback",
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF     = "TCS.urls"
WSGI_APPLICATION = "TCS.wsgi.application"
ASGI_APPLICATION = "TCS.asgi.application"
AUTH_USER_MODEL  = "accounts.User"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
     "OPTIONS": {"min_length": 6}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE     = "Asia/Kuala_Lumpur"
USE_I18N      = True
USE_TZ        = True

STATIC_URL  = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ── Cloudinary ────────────────────────────────────────────────
CLOUDINARY_STORAGE = {
    "CLOUD_NAME": env("CLOUDINARY_CLOUD_NAME", default=""),
    "API_KEY":    env("CLOUDINARY_API_KEY",    default=""),
    "API_SECRET": env("CLOUDINARY_API_SECRET", default=""),
    "SECURE":     True,
}

CLOUDINARY_ROOT_FOLDER = env("CLOUDINARY_ROOT_FOLDER", default="tcs_studenthub")

DEFAULT_FILE_STORAGE = "cloudinary_storage.storage.MediaCloudinaryStorage"

MEDIA_URL  = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

# ── DRF ──────────────────────────────────────────────────────
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.AllowAny",
    ),
    "DEFAULT_FILTER_BACKENDS": (
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ),
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

# ── JWT ───────────────────────────────────────────────────────
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME":    timedelta(minutes=60),
    "REFRESH_TOKEN_LIFETIME":   timedelta(days=30),
    "ROTATE_REFRESH_TOKENS":    True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN":        True,
    "AUTH_HEADER_TYPES":        ("Bearer",),
}

# ── API Docs ──────────────────────────────────────────────────
SPECTACULAR_SETTINGS = {
    "TITLE":       "TCS — StudentHub API",
    "DESCRIPTION": "Backend API for Taylors College Social & Arcade Platform",
    "VERSION":     "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
}

# ── Media upload size limits ──────────────────────────────────
# These are enforced on the Django side before anything reaches Cloudinary.
# The Flutter app also validates client-side so users get instant feedback.
#
# Images  — post photos, avatars, covers, arcade avatars
#   8 MB is comfortably above any phone camera shot after 85 % compression.
# Videos  — arcade clips and future video posts
#   50 MB ≈ 2–3 minutes of 720p mobile video.
MAX_IMAGE_MB = env.int("MAX_IMAGE_MB", default=8)
MAX_VIDEO_MB = env.int("MAX_VIDEO_MB", default=50)
MAX_AUDIO_MB = env.int("MAX_AUDIO_MB", default=15)
MAX_FILE_MB  = env.int("MAX_FILE_MB",  default=20)

# Convenience constants in bytes (used directly in views)
MAX_IMAGE_BYTES = MAX_IMAGE_MB * 1024 * 1024   # 8 388 608
MAX_VIDEO_BYTES = MAX_VIDEO_MB * 1024 * 1024   # 52 428 800
MAX_AUDIO_BYTES = MAX_AUDIO_MB * 1024 * 1024
MAX_FILE_BYTES  = MAX_FILE_MB  * 1024 * 1024

# Allowed MIME types accepted by the upload endpoint
ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp", "image/gif"]
ALLOWED_VIDEO_TYPES = ["video/mp4", "video/quicktime", "video/x-m4v", "video/mpeg"]

# ── Celery ────────────────────────────────────────────────────
CELERY_RESULT_BACKEND    = "django-db"
CELERY_ACCEPT_CONTENT    = ["json"]
CELERY_TASK_SERIALIZER   = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE          = TIME_ZONE
CELERY_BEAT_SCHEDULER    = "django_celery_beat.schedulers:DatabaseScheduler"

# ── Logging ───────────────────────────────────────────────────
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {"format": "[{asctime}] {levelname} {name}: {message}", "style": "{"},
    },
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "verbose"},
    },
    "root":    {"handlers": ["console"], "level": "INFO"},
    "loggers": {
        "django": {"handlers": ["console"], "level": "WARNING"},
        "apps":   {"handlers": ["console"], "level": "DEBUG"},
    },
}