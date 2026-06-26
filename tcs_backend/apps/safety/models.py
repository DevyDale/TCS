# apps/safety/models.py
#
# Unified emergency system: one EmergencyAlert with a `type` field covers
# lockdown / weather / medical / evacuation / … One FCM path, one banner, one
# history. Evacuation is just `type=evacuation` (warden-gated, mandatory ack).
#
# An app alert SUPPLEMENTS official emergency channels and procedures — it
# never replaces the building alarm or warden instructions.

import uuid

from django.conf import settings
from django.db import models


class EmergencyAlert(models.Model):
    class Type(models.TextChoices):
        LOCKDOWN   = "lockdown",   "Lockdown"
        EVACUATION = "evacuation", "Evacuation"   # warden-gated
        WEATHER    = "weather",    "Severe weather"
        MEDICAL    = "medical",    "Medical"
        SECURITY   = "security",   "Security threat"
        MISSING    = "missing",    "Missing person"
        CLOSURE    = "closure",    "Campus closure"
        HEALTH     = "health",     "Health / disease"
        OUTAGE     = "outage",     "Utility / IT outage"
        GENERAL    = "general",    "General alert"

    class Severity(models.TextChoices):
        INFO     = "info",     "Info"
        HIGH     = "high",     "High"
        CRITICAL = "critical", "Critical"

    class Audience(models.TextChoices):
        STAFF    = "staff",    "Staff"
        STUDENTS = "students", "Students"
        EVERYONE = "everyone", "Everyone"

    class Status(models.TextChoices):
        ACTIVE   = "active",   "Active"
        RESOLVED = "resolved", "Resolved"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    type        = models.CharField(max_length=12, choices=Type.choices)
    severity    = models.CharField(max_length=8,  choices=Severity.choices,
                                   default=Severity.HIGH)
    audience    = models.CharField(max_length=8,  choices=Audience.choices)
    title       = models.CharField(max_length=120)
    message     = models.TextField()
    instruction = models.CharField(max_length=300, blank=True, default="")
    zone        = models.CharField(max_length=80, blank=True, default="")
    is_drill    = models.BooleanField(default=False)
    status      = models.CharField(max_length=8, choices=Status.choices,
                                   default=Status.ACTIVE, db_index=True)

    posted_by      = models.ForeignKey(settings.AUTH_USER_MODEL,
                                       on_delete=models.PROTECT,
                                       related_name="emergencies_posted")
    posted_by_name = models.CharField(max_length=120, blank=True, default="")
    posted_at      = models.DateTimeField(auto_now_add=True, db_index=True)
    resolved_by    = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                       on_delete=models.SET_NULL,
                                       related_name="emergencies_resolved")
    resolved_at    = models.DateTimeField(null=True, blank=True)
    expires_at     = models.DateTimeField(null=True, blank=True)   # auto all-clear
    is_deleted     = models.BooleanField(default=False, db_index=True)  # soft-delete

    class Meta:
        db_table = "safety_emergency_alert"
        ordering = ["-posted_at"]

    @property
    def requires_checkin(self):
        return self.type == self.Type.EVACUATION


class EmergencyUpdate(models.Model):
    """Appended timeline entries on a live alert — situations evolve."""
    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    alert       = models.ForeignKey(EmergencyAlert, on_delete=models.CASCADE,
                                    related_name="updates")
    author      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
                                    related_name="+")
    author_name = models.CharField(max_length=120, blank=True, default="")
    text        = models.TextField()
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "safety_emergency_update"
        ordering = ["created_at"]


class EmergencyAck(models.Model):
    """Acknowledge / 'I'm safe' check-in — doubles as the evacuation roster."""
    id        = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    alert     = models.ForeignKey(EmergencyAlert, on_delete=models.CASCADE,
                                  related_name="acks")
    user      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                  related_name="+")
    user_name = models.CharField(max_length=120, blank=True, default="")
    acked_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "safety_emergency_ack"
        unique_together = [("alert", "user")]
        ordering = ["-acked_at"]


class EmergencyAudit(models.Model):
    """Append-only: post / update / resolve / delete, by whom, when."""
    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    alert      = models.ForeignKey(EmergencyAlert, on_delete=models.CASCADE,
                                   related_name="audit")
    actor      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
                                   related_name="+")
    actor_name = models.CharField(max_length=120, blank=True, default="")
    action     = models.CharField(max_length=20)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "safety_emergency_audit"
        ordering = ["-created_at"]
