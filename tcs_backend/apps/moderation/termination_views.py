# apps/moderation/termination_views.py
#
# Student termination & the escalation ladder's terminal action.
#
# Safety model:
#   • Whole feature is Staff-gated (IsStaff).
#   • PERMANENT termination is restricted to admins / safeguarding leads.
#   • Any SAFETY / child-safety reason is HARD-ROUTED to a safeguarding lead and
#     is NEVER actioned as a normal termination by general staff (or AI).
#   • Enforcement is roster-level: a sealed TerminationRecord keyed on
#     (student_id, DOB) bars access at BOTH registration and login, independent
#     of whether the User row still exists.

import logging

from django.contrib.auth import get_user_model
from django.db import models, transaction
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from apps.accounts.permissions import IsStaff
from .models import TerminationRecord, ChildSafetyCase
from .staff_views import (_is_safeguarding_lead, record_audit,
                          _notify_safeguarding_leads)

User = get_user_model()
logger = logging.getLogger(__name__)

_VALID_REASONS = {c[0] for c in TerminationRecord.Reason.choices}


# ── helpers ──────────────────────────────────────────────────────────────

def _actor_name(u):
    return getattr(u, "display_name", "") or getattr(u, "name", "") or ""


def _content_snapshot(user, rec):
    """A counts snapshot taken at termination time — survives the soft-delete
    of the live content so the sealed record still shows the footprint."""
    snap = {"taken_at": timezone.now().isoformat()}
    if rec is not None:
        snap["course_type"] = getattr(rec, "course_type", "")
    if user is not None:
        try:
            from apps.posts.models import Post, Comment
            snap["posts"] = Post.objects.filter(author=user).count()
            snap["comments"] = Comment.objects.filter(author=user).count()
        except Exception:
            pass
        try:
            from apps.chat.models import Message
            snap["messages"] = Message.objects.filter(sender=user).count()
        except Exception:
            pass
    return snap


def _ban_user(user, reason):
    """Hard-ban the live account: suspend, deactivate, purge push token."""
    user.is_suspended = True
    user.suspended_reason = (reason or "Terminated")[:255]
    user.suspended_at = timezone.now()
    user.is_active = False
    user.fcm_token = ""
    user.save(update_fields=["is_suspended", "suspended_reason",
                             "suspended_at", "is_active", "fcm_token"])


def _revoke_tokens(user):
    """Blacklist every outstanding refresh token so all sessions die now."""
    try:
        from rest_framework_simplejwt.token_blacklist.models import (
            OutstandingToken, BlacklistedToken,
        )
        for tok in OutstandingToken.objects.filter(user=user):
            BlacklistedToken.objects.get_or_create(token=tok)
    except Exception:
        logger.exception("token revoke failed for %s", getattr(user, "user_id", "?"))


def _soft_delete_content(user):
    """Hide the student's content from other students — soft-delete only, never
    a hard delete, so the internal record survives."""
    try:
        from apps.posts.models import Post, Comment
        Post.objects.filter(author=user).update(is_flagged=True)
        Comment.objects.filter(author=user).update(is_deleted=True)
    except Exception:
        logger.exception("post/comment soft-delete failed")
    try:
        from apps.chat.models import Message
        Message.objects.filter(sender=user).update(is_deleted=True, text="")
    except Exception:
        logger.exception("message soft-delete failed")


def _route_to_safeguarding(actor, student_id, name, note, user):
    """Child-safety reason: never a normal termination. Open a preserved
    safeguarding case and alert the leads. Leads then work it via the existing
    child-safety flow."""
    case = ChildSafetyCase.objects.create(
        raised_by=actor, raised_by_name=_actor_name(actor),
        subject_user=user, subject_name=name or student_id,
        severity=ChildSafetyCase.Severity.URGENT,
        status=ChildSafetyCase.Status.OPEN,
        reason=(note or "Safety concern raised via termination flow")[:300],
        preserved={"student_id": student_id, "source": "termination_flow",
                   "raised_at": timezone.now().isoformat()},
    )
    try:
        _notify_safeguarding_leads(actor, case)
    except Exception:
        logger.exception("lead notify failed")
    record_audit(actor, "termination.routed_child_safety",
                 f"Safety reason for {name or student_id} routed to leads",
                 "student", student_id)
    return case


def _record_dict(r):
    return {
        "id":            str(r.id),
        "student_id":    r.student_id,
        "full_name":     r.full_name,
        "reason":        r.reason,
        "reason_label":  dict(TerminationRecord.Reason.choices).get(r.reason, r.reason),
        "note":          r.note,
        "is_permanent":  r.is_permanent,
        "is_active":     r.is_active,
        "terminated_by": r.terminated_by_name,
        "evidence":      r.evidence,
        "created_at":    r.created_at.isoformat(),
    }


# ── endpoints ────────────────────────────────────────────────────────────

@api_view(["POST"])
@permission_classes([IsStaff])
def terminate_student(request):
    """POST /api/moderation/staff/terminate/
    body: {student_id, reason, note, confirm_id, permanent?}"""
    data       = request.data
    student_id = (data.get("student_id") or "").strip()
    reason     = (data.get("reason") or "").strip()
    note       = (data.get("note") or "").strip()
    confirm    = (data.get("confirm_id") or "").strip()
    permanent  = bool(data.get("permanent", True))

    if not student_id:
        return Response({"error": "student_id is required."}, status=400)
    if reason not in _VALID_REASONS:
        return Response({"error": "A valid reason category is required."}, status=400)
    if not note:
        return Response({"error": "A reason note is required."}, status=400)
    # Typed confirmation — staff must retype the exact student ID.
    if confirm != student_id:
        return Response(
            {"error": "Type the exact student ID to confirm this action."},
            status=400)

    from apps.dataentry.models import StudentRecord
    rec  = StudentRecord.objects.filter(student_id=student_id).first()
    dob  = rec.date_of_birth if rec else None
    name = (rec.full_name if rec else "") or (data.get("full_name") or "")
    user = User.objects.filter(user_id=student_id).first()

    # SAFETY reason → hard route to a safeguarding lead; do NOT terminate here.
    if reason == TerminationRecord.Reason.SAFETY:
        _route_to_safeguarding(request.user, student_id, name, note, user)
        return Response({
            "routed": True,
            "message": "This has a safety / child-safety reason, so it has been "
                       "routed to a safeguarding lead. It is not actioned as a "
                       "normal termination.",
        }, status=202)

    # Permanent termination is lead/admin only.
    if permanent and not _is_safeguarding_lead(request.user):
        return Response(
            {"error": "Permanent termination is restricted to admins and "
                      "safeguarding leads."},
            status=403)

    with transaction.atomic():
        if user is not None:
            user = (User.objects.select_for_update(of=("self",))
                    .get(pk=user.pk))
            evidence = _content_snapshot(user, rec)
            _ban_user(user, note)
            _revoke_tokens(user)
            _soft_delete_content(user)
        else:
            evidence = _content_snapshot(None, rec)

        record = TerminationRecord.objects.create(
            student_id=student_id, date_of_birth=dob, full_name=name,
            reason=reason, note=note, is_permanent=permanent, is_active=True,
            terminated_by=request.user, terminated_by_name=_actor_name(request.user),
            evidence=evidence,
        )

    record_audit(request.user, "student.terminated",
                 f"{name or student_id} ({student_id}) — {reason}"
                 f"{' [permanent]' if permanent else ''}",
                 "student", student_id)
    return Response(_record_dict(record), status=201)


@api_view(["GET"])
@permission_classes([IsStaff])
def termination_log(request):
    """GET /api/moderation/staff/terminations/  — append-only history, with
    filters (reason, staff, date range, q)."""
    qs = TerminationRecord.objects.select_related("terminated_by").all()

    reason = request.query_params.get("reason")
    if reason:
        qs = qs.filter(reason=reason)
    staff = request.query_params.get("staff")
    if staff:
        qs = qs.filter(terminated_by_name__icontains=staff)
    q = request.query_params.get("q")
    if q:
        qs = qs.filter(models.Q(student_id__icontains=q) |
                       models.Q(full_name__icontains=q))
    since = request.query_params.get("since")
    if since:
        qs = qs.filter(created_at__date__gte=since)
    until = request.query_params.get("until")
    if until:
        qs = qs.filter(created_at__date__lte=until)

    rows = [_record_dict(r) for r in qs[:500]]
    return Response({"results": rows, "count": len(rows)})


@api_view(["POST"])
@permission_classes([IsStaff])
def lift_termination(request, pk):
    """POST /api/moderation/staff/terminations/<id>/lift/  — appeal outcome:
    lift the bar. Leads/admins only. Sealed fields are untouched; only the
    active flag flips, and it's audited."""
    if not _is_safeguarding_lead(request.user):
        return Response(
            {"error": "Only admins / safeguarding leads can lift a termination."},
            status=403)
    try:
        rec = TerminationRecord.objects.get(pk=pk)
    except TerminationRecord.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    rec.is_active = False
    rec.save(update_fields=["is_active"])

    # Best-effort: also lift the live account's suspension so they can log in.
    user = User.objects.filter(user_id=rec.student_id).first()
    if user:
        user.is_suspended = False
        user.is_active = True
        user.suspended_reason = ""
        user.save(update_fields=["is_suspended", "is_active", "suspended_reason"])

    record_audit(request.user, "student.termination_lifted",
                 f"Bar lifted for {rec.full_name or rec.student_id}",
                 "student", rec.student_id)
    return Response(_record_dict(rec))
