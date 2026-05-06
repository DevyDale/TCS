import os
from celery import Celery
from celery.schedules import crontab

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "TCS.settings.development")

app = Celery("TCS")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()

app.conf.beat_schedule = {
    "event-reminders-hourly": {
        "task": "push_event_reminders",
        "schedule": crontab(minute=0),
    },
    "expire-game-requests-daily": {
        "task": "expire_game_requests",
        "schedule": crontab(hour=2, minute=0),
    },
    "update-active-counts": {
        "task": "update_group_active_counts",
        "schedule": crontab(minute="*/5"),
    },
}
