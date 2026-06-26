# apps/studyhub/models.py
#
# The teacher <-> student bridge of the Study Hub. Phase 1-3 of the spec:
# teacher availability (office hours), a shared Resource library (teacher
# uploads, students browse), and a Q&A / doubt board (students ask, teachers
# and peers answer). Files go to the default Cloudinary storage; everything
# else is plain columns. Hand-written migrations only.

import uuid

from django.conf import settings
from django.db import models


class TeacherAvailability(models.Model):
    """A teacher's office-hours signal: which subjects, open now or not."""
    teacher    = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                       related_name="teaching_availability")
    subjects   = models.CharField(max_length=200, blank=True, default="")  # comma-separated
    note       = models.CharField(max_length=200, blank=True, default="")
    is_open    = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "studyhub_availability"


class Resource(models.Model):
    class Kind(models.TextChoices):
        NOTE  = "note",  "Note"
        PAPER = "paper", "Past paper"
        GUIDE = "guide", "Guide"
        LINK  = "link",  "Link"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="study_resources")
    subject     = models.CharField(max_length=80, db_index=True)
    title       = models.CharField(max_length=160)
    kind        = models.CharField(max_length=6, choices=Kind.choices, default=Kind.NOTE)
    file        = models.FileField(upload_to="studyhub/resources/", blank=True, null=True)
    link_url    = models.URLField(blank=True, default="")
    verified_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                    on_delete=models.SET_NULL, related_name="verified_resources")
    downloads   = models.PositiveIntegerField(default=0)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "studyhub_resource"
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["subject", "-created_at"], name="sh_res_subj_idx")]


class Question(models.Model):
    class Status(models.TextChoices):
        OPEN     = "open",     "Open"
        RESOLVED = "resolved", "Resolved"

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    asker      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name="study_questions")
    subject    = models.CharField(max_length=80, db_index=True)
    title      = models.CharField(max_length=200)
    body       = models.TextField(blank=True, default="")
    status     = models.CharField(max_length=8, choices=Status.choices,
                                  default=Status.OPEN, db_index=True)
    upvotes    = models.PositiveIntegerField(default=0)
    voters     = models.JSONField(default=list)   # user ids who upvoted (idempotent)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "studyhub_question"
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["status", "-created_at"], name="sh_q_status_idx")]


class Answer(models.Model):
    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    question    = models.ForeignKey(Question, on_delete=models.CASCADE, related_name="answers")
    author      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="study_answers")
    body        = models.TextField()
    is_teacher  = models.BooleanField(default=False)   # teacher-authored badge
    is_accepted = models.BooleanField(default=False)
    upvotes     = models.PositiveIntegerField(default=0)
    voters      = models.JSONField(default=list)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "studyhub_answer"
        ordering = ["-is_accepted", "-upvotes", "created_at"]
