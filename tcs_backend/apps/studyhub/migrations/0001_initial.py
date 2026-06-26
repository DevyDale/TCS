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
            name="TeacherAvailability",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True,
                                           serialize=False, verbose_name="ID")),
                ("subjects", models.CharField(blank=True, default="", max_length=200)),
                ("note", models.CharField(blank=True, default="", max_length=200)),
                ("is_open", models.BooleanField(default=False)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("teacher", models.OneToOneField(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="teaching_availability", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "studyhub_availability"},
        ),
        migrations.CreateModel(
            name="Resource",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("subject", models.CharField(db_index=True, max_length=80)),
                ("title", models.CharField(max_length=160)),
                ("kind", models.CharField(choices=[
                    ("note", "Note"), ("paper", "Past paper"),
                    ("guide", "Guide"), ("link", "Link")],
                    default="note", max_length=6)),
                ("file", models.FileField(blank=True, null=True,
                                          upload_to="studyhub/resources/")),
                ("link_url", models.URLField(blank=True, default="")),
                ("downloads", models.PositiveIntegerField(default=0)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("owner", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="study_resources", to=settings.AUTH_USER_MODEL)),
                ("verified_by", models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="verified_resources", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "studyhub_resource", "ordering": ["-created_at"]},
        ),
        migrations.AddIndex(
            model_name="resource",
            index=models.Index(fields=["subject", "-created_at"], name="sh_res_subj_idx"),
        ),
        migrations.CreateModel(
            name="Question",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("subject", models.CharField(db_index=True, max_length=80)),
                ("title", models.CharField(max_length=200)),
                ("body", models.TextField(blank=True, default="")),
                ("status", models.CharField(choices=[
                    ("open", "Open"), ("resolved", "Resolved")],
                    db_index=True, default="open", max_length=8)),
                ("upvotes", models.PositiveIntegerField(default=0)),
                ("voters", models.JSONField(default=list)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("asker", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="study_questions", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "studyhub_question", "ordering": ["-created_at"]},
        ),
        migrations.AddIndex(
            model_name="question",
            index=models.Index(fields=["status", "-created_at"], name="sh_q_status_idx"),
        ),
        migrations.CreateModel(
            name="Answer",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("body", models.TextField()),
                ("is_teacher", models.BooleanField(default=False)),
                ("is_accepted", models.BooleanField(default=False)),
                ("upvotes", models.PositiveIntegerField(default=0)),
                ("voters", models.JSONField(default=list)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("author", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="study_answers", to=settings.AUTH_USER_MODEL)),
                ("question", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="answers", to="studyhub.question")),
            ],
            options={"db_table": "studyhub_answer",
                     "ordering": ["-is_accepted", "-upvotes", "created_at"]},
        ),
    ]
