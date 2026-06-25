import uuid
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("moderation", "0002_wellbeingaction"),
    ]

    operations = [
        migrations.CreateModel(
            name="AuditEvent",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("actor_name", models.CharField(blank=True, default="", max_length=120)),
                ("action", models.CharField(db_index=True, max_length=64)),
                ("summary", models.CharField(blank=True, default="", max_length=300)),
                ("target_type", models.CharField(blank=True, default="", max_length=32)),
                ("target_id", models.CharField(blank=True, default="", max_length=64)),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("actor", models.ForeignKey(blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "moderation_audit_event",
                "ordering": ["-created_at"],
            },
        ),
    ]
