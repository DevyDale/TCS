# apps/wellbeing/models.py
#
# Safeguarding signal store. A scored AI exchange (the derived signal, NOT the
# chat) and the triage Case raised when a signal crosses the severe threshold.
# Privacy-by-design: store a risk score + theme tags + a SHORT redacted snippet,
# never the full transcript. Its own app = its own permission boundary.

import uuid

from django.conf import settings
from django.db import models


class WellbeingSignal(models.Model):
    class Tier(models.TextChoices):
        THRIVING   = "thriving",   "Thriving"
        OKAY       = "okay",       "Okay"
        STRUGGLING = "struggling", "Struggling"
        AT_RISK    = "at_risk",    "At-risk"

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name="wellbeing_signals")
    tier       = models.CharField(max_length=12, choices=Tier.choices)
    risk_score = models.FloatField(default=0.0)            # 0.0 calm → 1.0 acute
    themes     = models.JSONField(default=list)            # ["academic", …]
    snippet    = models.TextField(blank=True, default="")  # short, redacted
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "wellbeing_signal"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["tier", "created_at"]),
            models.Index(fields=["student", "created_at"]),
        ]


class WellbeingCase(models.Model):
    class Severity(models.TextChoices):
        WATCH    = "watch",    "Watch"
        HIGH     = "high",     "High"
        CRITICAL = "critical", "Critical"

    class Status(models.TextChoices):
        OPEN         = "open",         "Open"
        ACKNOWLEDGED = "acknowledged", "Acknowledged"
        IN_PROGRESS  = "in_progress",  "In progress"
        ESCALATED    = "escalated",    "Escalated"
        RESOLVED     = "resolved",     "Resolved"
        DISMISSED    = "dismissed",    "Dismissed (false positive)"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    signal      = models.OneToOneField(WellbeingSignal, on_delete=models.PROTECT,
                                       related_name="case")
    student     = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="wellbeing_cases")
    severity    = models.CharField(max_length=10, choices=Severity.choices)
    status      = models.CharField(max_length=14, choices=Status.choices,
                                   default=Status.OPEN, db_index=True)
    ai_reason   = models.TextField(blank=True, default="")
    assigned_to = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                    on_delete=models.SET_NULL, related_name="assigned_cases")
    dismiss_reason = models.TextField(blank=True, default="")
    created_at  = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "wellbeing_case"
        ordering = ["-severity", "-created_at"]


class CaseAction(models.Model):
    """Append-only audit trail — every view / status change / note."""
    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    case       = models.ForeignKey(WellbeingCase, on_delete=models.CASCADE,
                                   related_name="actions")
    actor      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
                                   related_name="+")
    actor_name = models.CharField(max_length=120, blank=True, default="")
    action     = models.CharField(max_length=40)   # viewed / acknowledged / …
    note       = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "wellbeing_case_action"
        ordering = ["created_at"]
