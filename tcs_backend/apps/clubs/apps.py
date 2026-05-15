# apps/clubs/apps.py
from django.apps import AppConfig


class ClubsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name               = "apps.clubs"

    def ready(self):
        from . import signals  # noqa: F401
    verbose_name       = "Clubs"