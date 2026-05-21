import uuid
from django.db import models
from django.conf import settings
from django.utils import timezone


class BlockedUser(models.Model):
    """
    A directional block: ``blocker`` has blocked ``blocked``.

    Drives Apple Guideline 1.2's "block abusive users" requirement:
      * the blocked user's content is stripped from the blocker's feed
        instantly (see apps.safety.utils.blocked_user_ids + the feed
        queryset patch in apps/posts/views.py), and
      * the blocker is hidden from the blocked user as well (enforced
        in both directions).
    """
    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    blocker    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name="blocks_made")
    blocked    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name="blocks_received")
    reason     = models.CharField(max_length=300, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table        = "blocked_users"
        ordering        = ["-created_at"]
        unique_together = ("blocker", "blocked")
        indexes = [
            models.Index(fields=["blocker"], name="blocked_blocker_idx"),
            models.Index(fields=["blocked"], name="blocked_blocked_idx"),
        ]

    def __str__(self):
        return f"{self.blocker} blocked {self.blocked}"


class Report(models.Model):
    """
    Unified moderation report. Targets a user, a post, or a comment.

    Created by either:
      * a user tapping "Report" in the app, or
      * the automated content filter on post create
        (``reason='auto_filter'``).

    Apple Guideline 1.2 requires the developer to act on objectionable
    content reports within 24 hours. ``is_overdue`` surfaces that SLA in
    the Django admin moderation queue.
    """

    class Target(models.TextChoices):
        USER    = "user",    "User"
        POST    = "post",    "Post"
        COMMENT = "comment", "Comment"

    class Reason(models.TextChoices):
        SPAM        = "spam",        "Spam or scam"
        HARASSMENT  = "harassment",  "Harassment or bullying"
        HATE        = "hate",        "Hate speech"
        VIOLENCE    = "violence",    "Violence or threats"
        SEXUAL      = "sexual",      "Sexual or explicit content"
        SELF_HARM   = "self_harm",   "Self-harm"
        OTHER       = "other",       "Other"
        AUTO_FILTER = "auto_filter", "Auto-flagged by content filter"

    class Status(models.TextChoices):
        PENDING   = "pending",   "Pending review"
        ACTIONED  = "actioned",  "Actioned"
        DISMISSED = "dismissed", "Dismissed"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reporter    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                    null=True, blank=True, related_name="reports_made")
    target_type = models.CharField(max_length=10, choices=Target.choices)
    target_id   = models.CharField(max_length=64)            # UUID / pk as string
    # Denormalised for the queue: the author of the offending content.
    offender    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    null=True, blank=True, related_name="reports_against")
    reason      = models.CharField(max_length=20, choices=Reason.choices,
                                   default=Reason.OTHER)
    detail      = models.TextField(blank=True)
    status      = models.CharField(max_length=10, choices=Status.choices,
                                   default=Status.PENDING)
    handled_by  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                    null=True, blank=True, related_name="reports_handled")
    handled_at  = models.DateTimeField(null=True, blank=True)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "moderation_reports"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "created_at"], name="report_status_idx"),
            models.Index(fields=["target_type", "target_id"], name="report_target_idx"),
        ]

    def __str__(self):
        return f"[{self.get_status_display()}] {self.target_type}:{self.target_id} — {self.reason}"

    @property
    def is_overdue(self):
        """True if a pending report is older than the 24h Apple SLA."""
        if self.status != self.Status.PENDING:
            return False
        return (timezone.now() - self.created_at) > timezone.timedelta(hours=24)
