import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("moderation", "0004_emergencybroadcast_saferesponse"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="ChildSafetyCase",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("raised_by_name", models.CharField(blank=True, default="", max_length=120)),
                ("subject_name", models.CharField(blank=True, default="", max_length=120)),
                ("severity", models.CharField(choices=[
                    ("review", "Review"), ("urgent", "Urgent"), ("critical", "Critical")],
                    default="urgent", max_length=10)),
                ("status", models.CharField(choices=[
                    ("open", "Open — needs review"),
                    ("preserved", "Evidence preserved"),
                    ("reported", "Reported to authorities"),
                    ("closed", "Closed")],
                    db_index=True, default="preserved", max_length=10)),
                ("reason", models.CharField(blank=True, default="", max_length=300)),
                ("preserved", models.JSONField(default=dict)),
                ("notes", models.TextField(blank=True, default="")),
                ("outcome", models.TextField(blank=True, default="")),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("closed_by", models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
                ("raised_by", models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
                ("report", models.OneToOneField(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="child_safety_case", to="moderation.report")),
                ("subject_user", models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="child_safety_cases", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "moderation_child_safety_case",
                     "ordering": ["-created_at"]},
        ),
        migrations.AddIndex(
            model_name="childsafetycase",
            index=models.Index(fields=["status", "-created_at"],
                               name="cs_case_status_idx"),
        ),
    ]
