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
            name="WellbeingSignal",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("tier", models.CharField(max_length=12, choices=[
                    ("thriving", "Thriving"), ("okay", "Okay"),
                    ("struggling", "Struggling"), ("at_risk", "At-risk")])),
                ("risk_score", models.FloatField(default=0.0)),
                ("themes", models.JSONField(default=list)),
                ("snippet", models.TextField(blank=True, default="")),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("student", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="wellbeing_signals", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "wellbeing_signal", "ordering": ["-created_at"]},
        ),
        migrations.AddIndex(
            model_name="wellbeingsignal",
            index=models.Index(fields=["tier", "created_at"],
                               name="wb_sig_tier_idx"),
        ),
        migrations.AddIndex(
            model_name="wellbeingsignal",
            index=models.Index(fields=["student", "created_at"],
                               name="wb_sig_student_idx"),
        ),
        migrations.CreateModel(
            name="WellbeingCase",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("severity", models.CharField(max_length=10, choices=[
                    ("watch", "Watch"), ("high", "High"), ("critical", "Critical")])),
                ("status", models.CharField(db_index=True, default="open",
                    max_length=14, choices=[
                        ("open", "Open"), ("acknowledged", "Acknowledged"),
                        ("in_progress", "In progress"), ("escalated", "Escalated"),
                        ("resolved", "Resolved"),
                        ("dismissed", "Dismissed (false positive)")])),
                ("ai_reason", models.TextField(blank=True, default="")),
                ("dismiss_reason", models.TextField(blank=True, default="")),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("assigned_to", models.ForeignKey(blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="assigned_cases", to=settings.AUTH_USER_MODEL)),
                ("signal", models.OneToOneField(
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name="case", to="wellbeing.wellbeingsignal")),
                ("student", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="wellbeing_cases", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "wellbeing_case",
                     "ordering": ["-severity", "-created_at"]},
        ),
        migrations.CreateModel(
            name="CaseAction",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("actor_name", models.CharField(blank=True, default="", max_length=120)),
                ("action", models.CharField(max_length=40)),
                ("note", models.TextField(blank=True, default="")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("actor", models.ForeignKey(
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name="+", to=settings.AUTH_USER_MODEL)),
                ("case", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="actions", to="wellbeing.wellbeingcase")),
            ],
            options={"db_table": "wellbeing_case_action", "ordering": ["created_at"]},
        ),
    ]
