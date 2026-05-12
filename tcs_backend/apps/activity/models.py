import uuid
from django.conf import settings
from django.db import models


class Activity(models.Model):
    """A single entry in a user's activity feed."""

    class Verb(models.TextChoices):
        GROUP_DISSOLVED = "group_dissolved", "Group dissolved"
        GROUP_JOINED    = "group_joined",    "Joined group"
        GROUP_LEFT      = "group_left",      "Left group"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Recipient — whose activity feed this lives in
    user        = models.ForeignKey(settings.AUTH_USER_MODEL,
                                    on_delete=models.CASCADE,
                                    related_name="activity_log")

    # Who performed the action (null if system)
    actor       = models.ForeignKey(settings.AUTH_USER_MODEL,
                                    on_delete=models.SET_NULL,
                                    null=True, blank=True,
                                    related_name="activities_performed")

    verb        = models.CharField(max_length=30, choices=Verb.choices)
    target_type = models.CharField(max_length=20, blank=True)
    target_id   = models.UUIDField(null=True, blank=True)
    target_name = models.CharField(max_length=200, blank=True)
    metadata    = models.JSONField(default=dict, blank=True)
    is_read     = models.BooleanField(default=False)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "activity_log"
        ordering = ["-created_at"]
        indexes  = [models.Index(fields=["user", "-created_at"])]

    def __str__(self):
        return f"{self.actor} {self.verb} {self.target_name} → {self.user}"
