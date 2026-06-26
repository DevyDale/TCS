import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("studyhub", "0001_initial"),
        ("groups", "0002_alter_groupmaterial_file"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="Quiz",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("subject", models.CharField(db_index=True, max_length=80)),
                ("title", models.CharField(max_length=160)),
                ("description", models.CharField(blank=True, default="", max_length=300)),
                ("source", models.CharField(choices=[
                    ("manual", "Manual"), ("ai", "AI-generated")],
                    default="manual", max_length=6)),
                ("is_published", models.BooleanField(default=False)),
                ("time_limit_s", models.PositiveIntegerField(blank=True, null=True)),
                ("xp_reward", models.PositiveIntegerField(default=20)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("owner", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="study_quizzes", to=settings.AUTH_USER_MODEL)),
                ("group", models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="study_quizzes", to="groups.group")),
            ],
            options={"db_table": "studyhub_quiz", "ordering": ["-created_at"]},
        ),
        migrations.AddIndex(
            model_name="quiz",
            index=models.Index(fields=["is_published", "-created_at"],
                               name="sh_quiz_pub_idx"),
        ),
        migrations.CreateModel(
            name="QuizQuestion",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("text", models.TextField()),
                ("options", models.JSONField(default=list)),
                ("correct_index", models.PositiveSmallIntegerField(default=0)),
                ("explanation", models.TextField(blank=True, default="")),
                ("order", models.PositiveSmallIntegerField(default=0)),
                ("quiz", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="questions", to="studyhub.quiz")),
            ],
            options={"db_table": "studyhub_quiz_question", "ordering": ["order"]},
        ),
        migrations.CreateModel(
            name="QuizAttempt",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("score", models.PositiveSmallIntegerField(default=0)),
                ("total", models.PositiveSmallIntegerField(default=0)),
                ("answers", models.JSONField(default=dict)),
                ("xp_awarded", models.PositiveIntegerField(default=0)),
                ("completed_at", models.DateTimeField(auto_now_add=True)),
                ("quiz", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="attempts", to="studyhub.quiz")),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="study_quiz_attempts", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "studyhub_quiz_attempt",
                     "ordering": ["-completed_at"]},
        ),
        migrations.AddIndex(
            model_name="quizattempt",
            index=models.Index(fields=["quiz", "-completed_at"], name="sh_qa_quiz_idx"),
        ),
    ]
