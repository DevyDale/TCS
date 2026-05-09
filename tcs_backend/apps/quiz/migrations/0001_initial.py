# Generated for the quiz app
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import uuid


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        # SavedMaterial must already exist; the FK below depends on it.
        ("chat", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="GeneratedQuiz",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                         primary_key=True, serialize=False)),
                ("title",         models.CharField(max_length=200)),
                ("subject",       models.CharField(blank=True, max_length=100)),
                ("difficulty",    models.CharField(
                    choices=[("easy", "Easy"), ("medium", "Medium"),
                             ("hard", "Hard"), ("mixed", "Mixed")],
                    default="medium", max_length=10)),
                ("num_questions", models.PositiveSmallIntegerField(default=10)),
                ("question_types", models.JSONField(default=list, help_text=(
                    "Subset of ['mcq','true_false','short']. Empty = all."))),
                ("questions",     models.JSONField(default=list)),
                ("tokens_used",   models.PositiveIntegerField(default=0)),
                ("model_name",    models.CharField(blank=True, max_length=60)),
                ("created_at",    models.DateTimeField(auto_now_add=True)),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="generated_quizzes",
                    to=settings.AUTH_USER_MODEL)),
                ("material", models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="quizzes", to="chat.savedmaterial")),
            ],
            options={
                "db_table": "generated_quizzes",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="generatedquiz",
            index=models.Index(fields=["user", "-created_at"],
                               name="gen_quiz_user_dt_idx"),
        ),
        migrations.CreateModel(
            name="QuizAttempt",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                         primary_key=True, serialize=False)),
                ("answers",          models.JSONField(default=dict)),
                ("score",            models.PositiveSmallIntegerField(default=0)),
                ("total",            models.PositiveSmallIntegerField(default=0)),
                ("percentage",       models.FloatField(default=0.0)),
                ("duration_seconds", models.PositiveIntegerField(default=0)),
                ("completed_at",     models.DateTimeField(auto_now_add=True)),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="quiz_attempts",
                    to=settings.AUTH_USER_MODEL)),
                ("quiz", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="attempts",
                    to="quiz.generatedquiz")),
            ],
            options={
                "db_table": "quiz_attempts",
                "ordering": ["-completed_at"],
            },
        ),
        migrations.AddIndex(
            model_name="quizattempt",
            index=models.Index(fields=["quiz", "-completed_at"],
                               name="quiz_att_quiz_dt_idx"),
        ),
    ]