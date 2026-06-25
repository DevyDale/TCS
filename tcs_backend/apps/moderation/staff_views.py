# apps/moderation/staff_views.py
#
# Staff-facing moderation: the reports queue + triage actions. Students
# create Reports (ReportCreateView); staff review and act on them here.

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

import logging

from apps.accounts.permissions import IsStaff
from .models import Report

User = get_user_model()
logger = logging.getLogger(__name__)

_ELEVATED_ROLES = ("teaching_staff", "admin")


def _is_elevated(user):
    return bool(getattr(user, "is_superuser", False)) or \
        (getattr(user, "role", "") or "").lower() in _ELEVATED_ROLES


def _owner_of(obj):
    """Best-effort: the user who owns/authored a reported object."""
    if obj is None:
        return None
    if isinstance(obj, User):
        return obj
    for attr in ("author", "user", "owner", "sender", "created_by"):
        u = getattr(obj, attr, None)
        if isinstance(u, User):
            return u
    return None


def _preview(obj):
    if obj is None:
        return "(content already removed)"
    if isinstance(obj, User):
        return getattr(obj, "display_name", "") or str(obj)
    for attr in ("content", "text", "body", "caption", "message", "title"):
        v = getattr(obj, attr, None)
        if isinstance(v, str) and v.strip():
            return v[:160]
    return str(obj)[:160]


def _serialize(report):
    obj   = report.content_object
    owner = _owner_of(obj)
    return {
        "id":              str(report.id),
        "reason":          report.reason,
        "reason_label":    report.get_reason_display(),
        "description":     report.description,
        "status":          report.status,
        "content_type":    report.content_type.model,
        "object_id":       str(report.object_id),
        "preview":         _preview(obj),
        "content_exists":  obj is not None,
        "content_hidden":  bool(getattr(obj, "is_flagged", False)
                                or getattr(obj, "is_hidden", False))
                           if obj is not None else False,
        "flag_count":      Report.objects.filter(
                               content_type=report.content_type,
                               object_id=report.object_id,
                               status=Report.Status.PENDING).count(),
        "reporter_name":   getattr(report.reporter, "display_name", "") or "",
        "owner_id":        str(owner.id) if owner else "",
        "owner_name":      (getattr(owner, "display_name", "") or "") if owner else "",
        "owner_suspended": bool(getattr(owner, "is_suspended", False)) if owner else False,
        "is_user_report":  isinstance(obj, User) or report.content_type.model == "user",
        "created_at":      report.created_at.isoformat(),
    }


@api_view(["GET"])
@permission_classes([IsStaff])
def report_queue(request):
    """GET /api/moderation/staff/reports/?status=pending|reviewed|actioned|dismissed|all"""
    status_filter = (request.GET.get("status") or "pending").strip()
    qs = Report.objects.select_related("reporter", "content_type")
    if status_filter != "all":
        qs = qs.filter(status=status_filter)
    qs = qs.order_by("-created_at")[:200]
    return Response({
        "results": [_serialize(r) for r in qs],
        "counts": {"pending": Report.objects.filter(status="pending").count()},
    })


@api_view(["POST"])
@permission_classes([IsStaff])
def report_action(request, pk):
    """POST /api/moderation/staff/reports/<pk>/action/  body: {action, reason?}

    actions: dismiss | review | remove_content | suspend_user | unsuspend_user
    """
    report = Report.objects.select_related("content_type", "reporter").filter(id=pk).first()
    if not report:
        return Response({"error": "Report not found."}, status=404)

    action = (request.data.get("action") or "").strip()
    reason = (request.data.get("reason") or "").strip()
    now    = timezone.now()

    if action == "dismiss":
        report.status = "dismissed"

    elif action == "review":
        report.status = "reviewed"

    elif action in ("hide_content", "unhide_content"):
        # Reversible soft-hide: posts use is_flagged (the feed excludes it);
        # other content types may expose is_hidden.
        obj = report.content_object
        if isinstance(obj, User):
            return Response(
                {"error": "Use suspend_user for a reported account."}, status=400)
        if obj is None:
            return Response({"error": "Content no longer exists."}, status=400)
        hide  = action == "hide_content"
        field = next((f for f in ("is_flagged", "is_hidden", "is_removed")
                      if hasattr(obj, f)), None)
        if not field:
            return Response(
                {"error": "This content type can't be hidden."}, status=400)
        setattr(obj, field, hide)
        try:
            obj.save(update_fields=[field])
        except Exception as e:
            return Response({"error": f"Could not update content: {e}"}, status=400)
        report.status = "actioned" if hide else "reviewed"

    elif action == "remove_content":
        obj = report.content_object
        if isinstance(obj, User):
            return Response(
                {"error": "Use suspend_user for a reported account."}, status=400)
        if obj is not None:
            try:
                obj.delete()  # hard delete, per moderation policy
            except Exception as e:
                return Response({"error": f"Could not remove content: {e}"}, status=400)
        report.status = "actioned"

    elif action == "suspend_user":
        if not _is_elevated(request.user):
            return Response(
                {"error": "Elevated staff access required to suspend."}, status=403)
        owner = _owner_of(report.content_object)
        if owner is None:
            return Response({"error": "Could not resolve a user to suspend."}, status=400)
        if owner.id == request.user.id:
            return Response({"error": "You cannot suspend yourself."}, status=400)
        owner.is_suspended     = True
        owner.suspended_reason = reason or report.get_reason_display()
        owner.suspended_at     = now
        owner.save(update_fields=["is_suspended", "suspended_reason", "suspended_at"])
        report.status = "actioned"

    elif action == "unsuspend_user":
        if not _is_elevated(request.user):
            return Response(
                {"error": "Elevated staff access required."}, status=403)
        owner = _owner_of(report.content_object)
        if owner is None:
            return Response({"error": "Could not resolve a user."}, status=400)
        owner.is_suspended     = False
        owner.suspended_reason = ""
        owner.suspended_at     = None
        owner.save(update_fields=["is_suspended", "suspended_reason", "suspended_at"])

    else:
        return Response({"error": f"Unknown action: {action}"}, status=400)

    report.reviewed_at = now
    report.reviewed_by = request.user
    report.save(update_fields=["status", "reviewed_at", "reviewed_by"])
    return Response(_serialize(report))


@api_view(["GET"])
@permission_classes([IsStaff])
def staff_overview(request):
    """GET /api/moderation/staff/overview/

    Cohort pulse for the Staff Home command center.
    """
    from apps.events.models import Event

    now   = timezone.now()
    today = timezone.localdate()

    active_today    = User.objects.filter(last_seen__date=today).count()
    flags_pending   = Report.objects.filter(status="pending").count()
    upcoming_events = Event.objects.filter(start_time__gte=now).count()

    return Response({
        "active_today":    active_today,
        "flags_pending":   flags_pending,
        "upcoming_events": upcoming_events,
    })


@api_view(["GET"])
@permission_classes([IsStaff])
def suspended_users(request):
    """GET /api/moderation/staff/suspended/  — list currently suspended users."""
    qs = User.objects.filter(is_suspended=True).order_by("-suspended_at")
    return Response([{
        "id":           str(u.id),
        "user_id":      getattr(u, "user_id", ""),
        "name":         getattr(u, "display_name", "") or getattr(u, "name", "")
                        or "User",
        "reason":       getattr(u, "suspended_reason", "") or "",
        "suspended_at": u.suspended_at.isoformat() if u.suspended_at else None,
        "avatar_url":   request.build_absolute_uri(u.avatar.url)
                        if getattr(u, "avatar", None) else None,
    } for u in qs])


@api_view(["POST"])
@permission_classes([IsStaff])
def restore_user(request, pk):
    """POST /api/moderation/staff/suspended/<id>/restore/  — lift a suspension."""
    if not _is_elevated(request.user):
        return Response({"error": "Elevated staff access required."}, status=403)
    try:
        u = User.objects.get(id=pk)
    except User.DoesNotExist:
        return Response({"error": "User not found."}, status=404)
    u.is_suspended     = False
    u.suspended_reason = ""
    u.suspended_at     = None
    u.save(update_fields=["is_suspended", "suspended_reason", "suspended_at"])
    return Response({"ok": True, "id": str(u.id)})


@api_view(["GET"])
@permission_classes([IsStaff])
def staff_roster(request):
    """GET /api/moderation/staff/roster/?q=&filter=all|active|quiet

    Searchable student roster with engagement signal (last seen / online).
    """
    from datetime import timedelta
    from django.db.models import Q

    q    = (request.GET.get("q") or "").strip()
    filt = (request.GET.get("filter") or "all").strip()
    now  = timezone.now()

    qs = User.objects.filter(role="student", is_active=True)
    if q:
        qs = qs.filter(Q(name__icontains=q) | Q(user_id__icontains=q))
    if filt == "active":
        qs = qs.filter(last_seen__gte=now - timedelta(days=2))
    elif filt == "quiet":
        qs = qs.filter(Q(last_seen__lt=now - timedelta(days=7)) |
                       Q(last_seen__isnull=True))
    users = list(qs.order_by("-is_online", "-last_seen")[:300])

    return Response({
        "count": len(users),
        "results": [{
            "id":         str(u.id),
            "user_id":    getattr(u, "user_id", ""),
            "name":       getattr(u, "display_name", "") or getattr(u, "name", "")
                          or "Student",
            "is_online":  bool(getattr(u, "is_online", False)),
            "suspended":  bool(getattr(u, "is_suspended", False)),
            "last_seen":  u.last_seen.isoformat() if getattr(u, "last_seen", None)
                          else None,
            "avatar_url": request.build_absolute_uri(u.avatar.url)
                          if getattr(u, "avatar", None) else None,
        } for u in users],
    })


@api_view(["GET"])
@permission_classes([IsStaff])
def wellbeing_queue(request):
    """GET /api/moderation/staff/wellbeing/

    Quiet-student signal: students who were normally active but have gone
    silent (last seen 7–45 days ago), excluding anyone a staffer has already
    attended to in the last 14 days. This is an early-support signal — NOT a
    clinical assessment.
    """
    from datetime import timedelta
    from .models import WellbeingAction

    now = timezone.now()
    quiet_lo = now - timedelta(days=45)   # not long-gone / graduated
    quiet_hi = now - timedelta(days=7)    # silent at least a week
    recent_action = now - timedelta(days=14)

    handled_ids = set(WellbeingAction.objects
        .filter(created_at__gte=recent_action)
        .values_list("student_id", flat=True))

    qs = (User.objects
        .filter(role="student", is_active=True,
                last_seen__gte=quiet_lo, last_seen__lt=quiet_hi)
        .exclude(id__in=handled_ids)
        .order_by("last_seen")[:100])

    out = []
    for u in qs:
        days = (now - u.last_seen).days if u.last_seen else None
        out.append({
            "id":         str(u.id),
            "user_id":    getattr(u, "user_id", ""),
            "name":       getattr(u, "display_name", "") or getattr(u, "name", "")
                          or "Student",
            "days_quiet": days,
            "signal":     f"Quiet for {days} days (normally active)",
            "last_seen":  u.last_seen.isoformat() if u.last_seen else None,
            "avatar_url": request.build_absolute_uri(u.avatar.url)
                          if getattr(u, "avatar", None) else None,
        })
    return Response({"results": out})


@api_view(["POST"])
@permission_classes([IsStaff])
def wellbeing_action(request, pk):
    """POST /api/moderation/staff/wellbeing/<student_id>/action/
       body: {action: reach_out|escalate|handled, note?}

    Logs the action (so the student drops off the queue) and, for 'escalate',
    notifies senior staff in-app. This is in-app routing, not a substitute for
    the college's formal welfare process.
    """
    from .models import WellbeingAction

    action = (request.data.get("action") or "").strip()
    note   = (request.data.get("note") or "").strip()
    if action not in ("reach_out", "escalate", "handled"):
        return Response({"error": "Unknown action."}, status=400)
    try:
        student = User.objects.get(id=pk)
    except User.DoesNotExist:
        return Response({"error": "Student not found."}, status=404)

    WellbeingAction.objects.create(
        student=student, staff=request.user, kind=action, note=note)

    if action == "escalate":
        try:
            from apps.notifications.tasks import _create
            name = (getattr(student, "display_name", "") or
                    getattr(student, "name", "") or "a student")
            actor = (getattr(request.user, "display_name", "") or "A staff member")
            seniors = User.objects.filter(
                role__in=("teaching_staff", "admin"), is_active=True
            ).exclude(id=request.user.id)
            for s in seniors:
                _create(str(s.id), str(request.user.id), "wellbeing",
                        "Wellbeing escalation",
                        f"{actor} escalated a wellbeing concern about {name}.",
                        "user", str(student.id))
        except Exception:
            logger.exception("wellbeing escalate notify failed")

    return Response({"ok": True, "action": action})
