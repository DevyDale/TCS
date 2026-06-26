import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("studyhub", "0002_quizzes"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="StudySession",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("subject", models.CharField(db_index=True, max_length=80)),
                ("title", models.CharField(max_length=160)),
                ("description", models.CharField(blank=True, default="", max_length=400)),
                ("when", models.DateTimeField(db_index=True)),
                ("location", models.CharField(blank=True, default="", max_length=160)),
                ("link", models.URLField(blank=True, default="")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("teacher", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="study_sessions", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "studyhub_session", "ordering": ["when"]},
        ),
        migrations.AddIndex(
            model_name="studysession",
            index=models.Index(fields=["when"], name="sh_sess_when_idx"),
        ),
        migrations.CreateModel(
            name="SessionRSVP",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("session", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="rsvps", to="studyhub.studysession")),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="session_rsvps", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "studyhub_session_rsvp",
                     "unique_together": {("session", "user")}},
        ),
    ]
