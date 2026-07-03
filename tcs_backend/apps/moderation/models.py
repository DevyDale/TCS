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
        indexes  = [models.Index(fields=["student", "-created_at"],
                                  name="mod_wb_student_created_idx")]


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


class ChildSafetyCase(models.Model):
    """A safeguarding case raised when reported content may involve a minor
    (CSAE / sexual / grooming). Distinct from ordinary moderation: evidence is
    PRESERVED (never blind-deleted), the case is routed to a designated
    safeguarding lead, and every step is audited. The preserved snapshot keeps
    what's needed to escalate to authorities even after the live content is
    hidden from the platform."""

    class Status(models.TextChoices):
        OPEN     = "open",     "Open — needs review"
        PRESERVED = "preserved", "Evidence preserved"
        REPORTED = "reported", "Reported to authorities"
        CLOSED   = "closed",   "Closed"

    class Severity(models.TextChoices):
        REVIEW   = "review",   "Review"
        URGENT   = "urgent",   "Urgent"
        CRITICAL = "critical", "Critical"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    report      = models.OneToOneField("Report", null=True, blank=True,
                                       on_delete=models.SET_NULL, related_name="child_safety_case")
    raised_by   = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                    on_delete=models.SET_NULL, related_name="+")
    raised_by_name = models.CharField(max_length=120, blank=True, default="")
    subject_user   = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                       on_delete=models.SET_NULL, related_name="child_safety_cases")
    subject_name   = models.CharField(max_length=120, blank=True, default="")
    severity    = models.CharField(max_length=10, choices=Severity.choices,
                                   default=Severity.URGENT)
    status      = models.CharField(max_length=10, choices=Status.choices,
                                   default=Status.PRESERVED, db_index=True)
    reason      = models.CharField(max_length=300, blank=True, default="")
    # Evidence snapshot taken at escalation time — survives content deletion.
    preserved   = models.JSONField(default=dict)
    notes       = models.TextField(blank=True, default="")
    outcome     = models.TextField(blank=True, default="")
    closed_by   = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                    on_delete=models.SET_NULL, related_name="+")
    created_at  = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "moderation_child_safety_case"
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["status", "-created_at"],
                                name="cs_case_status_idx")]


class EmergencyBroadcast(models.Model):
    """A high-priority safety alert pushed to the whole student body — a tier
    above normal announcements (lockdown, severe weather, urgent safety). When
    require_safe is set, students are asked to mark themselves safe, giving
    staff a live roll-call."""

    class Severity(models.TextChoices):
        INFO     = "info",     "Info"
        WARNING  = "warning",  "Warning"
        CRITICAL = "critical", "Critical"

    id              = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    message         = models.TextField()
    severity        = models.CharField(max_length=12, choices=Severity.choices,
                                       default=Severity.WARNING)
    require_safe    = models.BooleanField(default=False)
    is_active       = models.BooleanField(default=True, db_index=True)
    created_by      = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                        on_delete=models.SET_NULL, related_name="+")
    created_by_name = models.CharField(max_length=120, blank=True, default="")
    created_at      = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "moderation_emergency_broadcast"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.severity}: {self.message[:40]}"


class SafeResponse(models.Model):
    """A student's 'I'm safe' acknowledgement of an EmergencyBroadcast."""

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    broadcast  = models.ForeignKey(EmergencyBroadcast, on_delete=models.CASCADE,
                                   related_name="responses")
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name="+")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "moderation_safe_response"
        ordering = ["-created_at"]
        unique_together = (("broadcast", "user"),)


class TerminationRecord(models.Model):
    """Sealed, append-only record of a student termination / escalation action.

    This row is BOTH the accountability record AND the enforcement key. Students
    authenticate against the roster (dataentry.StudentRecord) and the login view
    get_or_creates a User, so banning/deleting the User alone does NOT keep a
    terminated student out — they simply re-verify and a fresh User is minted.
    The (student_id, date_of_birth) pair on an ACTIVE record is what actually
    bars access, checked at both registration (verify_student) and login.

    Immutable by design: the sealed fields are never edited after creation. Only
    `is_active` may flip (via an appeal/lift by a lead), and that flip is itself
    audited. See is_blocked() for the enforcement check.
    """

    class Reason(models.TextChoices):
        CONDUCT     = "conduct",            "Serious misconduct"
        HARASSMENT  = "harassment",         "Harassment / bullying"
        ACADEMIC    = "academic_integrity", "Academic dishonesty"
        REPEAT      = "repeat_violations",  "Repeated violations"
        SAFETY      = "safety",             "Safety / child-safety"   # routes to lead
        OTHER       = "other",              "Other"

    id            = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Enforcement key — denormalised from the roster so it survives User deletion.
    student_id    = models.CharField(max_length=50, db_index=True)
    date_of_birth = models.DateField(null=True, blank=True)
    full_name     = models.CharField(max_length=150, blank=True, default="")

    reason        = models.CharField(max_length=24, choices=Reason.choices,
                                     default=Reason.CONDUCT, db_index=True)
    note          = models.TextField(blank=True, default="")

    # Permanent = a hard, lead-only bar. Non-permanent rows are used for the
    # escalation ladder / appeals bookkeeping.
    is_permanent  = models.BooleanField(default=True)
    # Whether this bar is currently in force. Only a lead may lift it (appeal).
    is_active     = models.BooleanField(default=True, db_index=True)

    terminated_by      = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                           on_delete=models.SET_NULL, related_name="+")
    terminated_by_name = models.CharField(max_length=120, blank=True, default="")

    # Snapshot taken at termination time (content counts, roster info) — survives
    # the soft-delete of the student's live content.
    evidence      = models.JSONField(default=dict)

    created_at    = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "moderation_termination_record"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["student_id", "is_active"],
                         name="term_sid_active_idx"),
            models.Index(fields=["reason", "-created_at"],
                         name="term_reason_idx"),
        ]

    def __str__(self):
        return f"TERMINATED {self.full_name} ({self.student_id}) [{self.reason}]"

    @classmethod
    def is_blocked(cls, student_id, date_of_birth=None):
        """True if there's an active bar for this roster identity. DOB is matched
        when supplied (defence in depth); student_id alone still bars, since the
        roster IDs are unique."""
        if not student_id:
            return False
        qs = cls.objects.filter(student_id=str(student_id).strip(), is_active=True)
        if date_of_birth:
            qs = qs.filter(models.Q(date_of_birth=date_of_birth) |
                           models.Q(date_of_birth__isnull=True))
        return qs.exists()
