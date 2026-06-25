import uuid
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("moderation", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="WellbeingAction",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("kind", models.CharField(max_length=16, choices=[
                    ("reach_out", "Reached out"),
                    ("escalate", "Escalated to staff"),
                    ("handled", "Marked handled"),
                ])),
                ("note", models.TextField(blank=True, default="")),
                ("created_at", models.DateTimeField(auto_now_add=True,
                                                    db_index=True)),
                ("staff", models.ForeignKey(blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
                ("student", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="wellbeing_actions",
                    to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "moderation_wellbeing_action",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="wellbeingaction",
            index=models.Index(fields=["student", "-created_at"],
                               name="mod_wb_student_created_idx"),
        ),
    ]
