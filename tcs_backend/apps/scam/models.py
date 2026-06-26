# apps/scam/models.py
#
# Scam intel store shared by the student Detector and staff Scam Watch.
# Students report scams (and check messages via the existing /ai/scam-check/);
# staff triage reports and publish campus alerts that show in the student feed.

import uuid

from django.conf import settings
from django.db import models

SCAM_TYPES = [
    ("visa_fee", "Visa / fee fraud"),
    ("tuition", "Tuition / payment"),
    ("accommodation", "Accommodation / rental"),
    ("job", "Fake job"),
    ("tax_deportation", "Tax / 'deportation' call"),
    ("romance_crypto", "Romance / crypto"),
    ("phishing", "Phishing link"),
    ("scholarship", "Scholarship fraud"),
    ("other", "Other"),
]


class ScamReport(models.Model):
    class Status(models.TextChoices):
        NEW       = "new",       "New"
        REVIEWING = "reviewing", "Reviewing"
        CONFIRMED = "confirmed", "Confirmed"
        DISMISSED = "dismissed", "Dismissed"

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                   null=True, blank=True, related_name="scam_reports")
    student_name = models.CharField(max_length=120, blank=True, default="")
    scam_type  = models.CharField(max_length=20, blank=True, default="other")
    content    = models.TextField()
    contact    = models.CharField(max_length=200, blank=True, default="")  # url/number/handle
    was_victim = models.BooleanField(default=False)        # → support, not blame
    status     = models.CharField(max_length=10, choices=Status.choices,
                                  default=Status.NEW, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "scam_report"
        ordering = ["-created_at"]


class ScamAlert(models.Model):
    """Staff-published campus warning shown in the student Detector feed."""
    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title      = models.CharField(max_length=120)
    body       = models.TextField()
    scam_type  = models.CharField(max_length=20, blank=True, default="other")
    posted_by  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                   null=True, related_name="scam_alerts")
    posted_by_name = models.CharField(max_length=120, blank=True, default="")
    is_active  = models.BooleanField(default=True, db_index=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    posted_at  = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "scam_alert"
        ordering = ["-posted_at"]


class ScamBlocklist(models.Model):
    """Known-bad urls/numbers/handles feeding the checker + auto-moderation."""
    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    value      = models.CharField(max_length=200, unique=True)
    kind       = models.CharField(max_length=12, default="url")  # url|phone|email|handle
    note       = models.CharField(max_length=200, blank=True, default="")
    added_by   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                   null=True, related_name="+")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "scam_blocklist"
        ordering = ["-created_at"]
