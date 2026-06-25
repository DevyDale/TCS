"""
Moderation models — implements Apple guideline 1.2 requirements for
user-generated content:
  • Report:         cross-model flagging via GenericForeignKey
  • Block:          user-level blocking with instant feed filtering
  • BlockedKeyword: simple keyword filter for objectionable content
"""
import uuid
from django.conf import settings
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from django.db import models


REASON_CHOICES = [
    ("spam",         "Spam or misleading"),
    ("harassment",   "Harassment or bullying"),
    ("hate_speech",  "Hate speech or symbols"),
    ("violence",     "Violence or dangerous content"),
    ("sexual",       "Sexual or adult content"),
    ("self_harm",    "Self-harm or suicide"),
    ("illegal",      "Illegal activity"),
    ("false_info",   "False information"),
    ("other",        "Other"),
]


class Report(models.Model):
    class Status(models.TextChoices):
        PENDING   = "pending",   "Pending"
        REVIEWED  = "reviewed",  "Reviewed (no action)"
        ACTIONED  = "actioned",  "Content removed / user banned"
        DISMISSED = "dismissed", "Dismissed"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name="reports_made",
    )

    # GenericForeignKey lets us report Posts, Comments, Users, anything
    content_type   = models.ForeignKey(ContentType, on_delete=models.CASCADE)
    object_id      = models.CharField(max_length=64)
    content_object = GenericForeignKey("content_type", "object_id")

    reason      = models.CharField(max_length=32, choices=REASON_CHOICES)
    description = models.TextField(blank=True, max_length=1000)
    status      = models.CharField(
        max_length=16, choices=Status.choices, default=Status.PENDING,
    )

    created_at  = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name="reports_reviewed",
    )

    class Meta:
        db_table = "moderation_reports"
        indexes = [
            models.Index(fields=["content_type", "object_id"]),
            models.Index(fields=["status", "-created_at"]),
        ]
        ordering = ["-created_at"]

    def __str__(self):
        return f"Report({self.reason}) {self.content_type}/{self.object_id}"


class Block(models.Model):
    """User A blocks User B — B's content disappears from A's feed instantly."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    blocker = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name="blocks_made",
    )
    blocked = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name="blocked_by",
    )
    reason     = models.CharField(max_length=32, blank=True, choices=REASON_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "moderation_blocks"
        unique_together = [("blocker", "blocked")]
        indexes = [models.Index(fields=["blocker", "blocked"])]
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.blocker_id} blocks {self.blocked_id}"


class BlockedKeyword(models.Model):
    keyword = models.CharField(max_length=100, unique=True)
    severity = models.CharField(
        max_length=16,
        choices=[("warn", "Warn (allow but flag)"), ("reject", "Reject submission")],
        default="reject",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "moderation_blocked_keywords"
        ordering = ["keyword"]

    def __str__(self):
        return self.keyword


class WellbeingAction(models.Model):
    """A staff action on a wellbeing signal (a quiet student). Logging these
    lets the queue drop students who've been attended to, and gives an audit
    trail for the duty-of-care story."""

    class Kind(models.TextChoices):
        REACH_OUT = "reach_out", "Reached out"
        ESCALATE  = "escalate",  "Escalated to staff"
        HANDLED   = "handled",   "Marked handled"

    id      = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student = models.ForeignKey(settings.AUTH_USER_MODEL,
                                on_delete=models.CASCADE,
                                related_name="wellbeing_actions")
    staff   = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                on_delete=models.SET_NULL, related_name="+")
    kind    = models.CharField(max_length=16, choices=Kind.choices)
    note    = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "moderation_wellbeing_action"
        ordering = ["-created_at"]
        indexes  = [models.Index(fields=["student", "-created_at"])]


class AuditEvent(models.Model):
    """Append-only log of staff actions — the accountability layer. Written by
    record_audit() from the staff action endpoints. actor_name is denormalised
    so the trail survives account deletion."""

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    actor       = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                    on_delete=models.SET_NULL, related_name="+")
    actor_name  = models.CharField(max_length=120, blank=True, default="")
    action      = models.CharField(max_length=64, db_index=True)
    summary     = models.CharField(max_length=300, blank=True, default="")
    target_type = models.CharField(max_length=32, blank=True, default="")
    target_id   = models.CharField(max_length=64, blank=True, default="")
    created_at  = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "moderation_audit_event"
        ordering = ["-created_at"]
