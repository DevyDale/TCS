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
            name="EmergencyAlert",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("type", models.CharField(max_length=12, choices=[
                    ("lockdown", "Lockdown"), ("evacuation", "Evacuation"),
                    ("weather", "Severe weather"), ("medical", "Medical"),
                    ("security", "Security threat"), ("missing", "Missing person"),
                    ("closure", "Campus closure"), ("health", "Health / disease"),
                    ("outage", "Utility / IT outage"), ("general", "General alert")])),
                ("severity", models.CharField(default="high", max_length=8, choices=[
                    ("info", "Info"), ("high", "High"), ("critical", "Critical")])),
                ("audience", models.CharField(max_length=8, choices=[
                    ("staff", "Staff"), ("students", "Students"),
                    ("everyone", "Everyone")])),
                ("title", models.CharField(max_length=120)),
                ("message", models.TextField()),
                ("instruction", models.CharField(blank=True, default="", max_length=300)),
                ("zone", models.CharField(blank=True, default="", max_length=80)),
                ("is_drill", models.BooleanField(default=False)),
                ("status", models.CharField(db_index=True, default="active",
                    max_length=8, choices=[("active", "Active"), ("resolved", "Resolved")])),
                ("posted_by_name", models.CharField(blank=True, default="", max_length=120)),
                ("posted_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("resolved_at", models.DateTimeField(blank=True, null=True)),
                ("expires_at", models.DateTimeField(blank=True, null=True)),
                ("is_deleted", models.BooleanField(db_index=True, default=False)),
                ("posted_by", models.ForeignKey(
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name="emergencies_posted", to=settings.AUTH_USER_MODEL)),
                ("resolved_by", models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="emergencies_resolved", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "safety_emergency_alert", "ordering": ["-posted_at"]},
        ),
        migrations.CreateModel(
            name="EmergencyUpdate",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("author_name", models.CharField(blank=True, default="", max_length=120)),
                ("text", models.TextField()),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("alert", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="updates", to="safety.emergencyalert")),
                ("author", models.ForeignKey(
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "safety_emergency_update", "ordering": ["created_at"]},
        ),
        migrations.CreateModel(
            name="EmergencyAck",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("user_name", models.CharField(blank=True, default="", max_length=120)),
                ("acked_at", models.DateTimeField(auto_now_add=True)),
                ("alert", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="acks", to="safety.emergencyalert")),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "safety_emergency_ack", "ordering": ["-acked_at"],
                     "unique_together": {("alert", "user")}},
        ),
        migrations.CreateModel(
            name="EmergencyAudit",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("actor_name", models.CharField(blank=True, default="", max_length=120)),
                ("action", models.CharField(max_length=20)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("actor", models.ForeignKey(
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
                ("alert", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="audit", to="safety.emergencyalert")),
            ],
            options={"db_table": "safety_emergency_audit", "ordering": ["-created_at"]},
        ),
    ]
