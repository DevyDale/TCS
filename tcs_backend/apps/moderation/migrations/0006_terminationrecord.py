import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("moderation", "0005_childsafetycase"),
    ]

    operations = [
        migrations.CreateModel(
            name="TerminationRecord",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("student_id", models.CharField(db_index=True, max_length=50)),
                ("date_of_birth", models.DateField(blank=True, null=True)),
                ("full_name", models.CharField(blank=True, default="", max_length=150)),
                ("reason", models.CharField(
                    choices=[
                        ("conduct", "Serious misconduct"),
                        ("harassment", "Harassment / bullying"),
                        ("academic_integrity", "Academic dishonesty"),
                        ("repeat_violations", "Repeated violations"),
                        ("safety", "Safety / child-safety"),
                        ("other", "Other"),
                    ],
                    db_index=True, default="conduct", max_length=24)),
                ("note", models.TextField(blank=True, default="")),
                ("is_permanent", models.BooleanField(default=True)),
                ("is_active", models.BooleanField(db_index=True, default=True)),
                ("terminated_by_name", models.CharField(blank=True, default="", max_length=120)),
                ("evidence", models.JSONField(default=dict)),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("terminated_by", models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "moderation_termination_record",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="terminationrecord",
            index=models.Index(fields=["student_id", "is_active"],
                               name="term_sid_active_idx"),
        ),
        migrations.AddIndex(
            model_name="terminationrecord",
            index=models.Index(fields=["reason", "-created_at"],
                               name="term_reason_idx"),
        ),
    ]
