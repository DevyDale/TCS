import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="ScamReport",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("student_name", models.CharField(blank=True, default="", max_length=120)),
                ("scam_type", models.CharField(blank=True, default="other", max_length=20)),
                ("content", models.TextField()),
                ("contact", models.CharField(blank=True, default="", max_length=200)),
                ("was_victim", models.BooleanField(default=False)),
                ("status", models.CharField(db_index=True, default="new", max_length=10,
                    choices=[("new", "New"), ("reviewing", "Reviewing"),
                             ("confirmed", "Confirmed"), ("dismissed", "Dismissed")])),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("student", models.ForeignKey(blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="scam_reports", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "scam_report", "ordering": ["-created_at"]},
        ),
        migrations.CreateModel(
            name="ScamAlert",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("title", models.CharField(max_length=120)),
                ("body", models.TextField()),
                ("scam_type", models.CharField(blank=True, default="other", max_length=20)),
                ("posted_by_name", models.CharField(blank=True, default="", max_length=120)),
                ("is_active", models.BooleanField(db_index=True, default=True)),
                ("expires_at", models.DateTimeField(blank=True, null=True)),
                ("posted_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("posted_by", models.ForeignKey(null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="scam_alerts", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "scam_alert", "ordering": ["-posted_at"]},
        ),
        migrations.CreateModel(
            name="ScamBlocklist",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("value", models.CharField(max_length=200, unique=True)),
                ("kind", models.CharField(default="url", max_length=12)),
                ("note", models.CharField(blank=True, default="", max_length=200)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("added_by", models.ForeignKey(null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "scam_blocklist", "ordering": ["-created_at"]},
        ),
    ]
