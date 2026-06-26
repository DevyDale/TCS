import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("moderation", "0003_auditevent"),
    ]

    operations = [
        migrations.CreateModel(
            name="EmergencyBroadcast",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("message", models.TextField()),
                ("severity", models.CharField(
                    choices=[("info", "Info"), ("warning", "Warning"),
                             ("critical", "Critical")],
                    default="warning", max_length=12)),
                ("require_safe", models.BooleanField(default=False)),
                ("is_active", models.BooleanField(db_index=True, default=True)),
                ("created_by_name", models.CharField(blank=True, default="",
                                                     max_length=120)),
                ("created_at", models.DateTimeField(auto_now_add=True,
                                                    db_index=True)),
                ("created_by", models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "moderation_emergency_broadcast",
                "ordering": ["-created_at"],
            },
        ),
        migrations.CreateModel(
            name="SafeResponse",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("broadcast", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="responses",
                    to="moderation.emergencybroadcast")),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "moderation_safe_response",
                "ordering": ["-created_at"],
                "unique_together": {("broadcast", "user")},
            },
        ),
    ]
