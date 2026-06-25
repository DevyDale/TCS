# apps/moderation/staff_views.py
#
# Staff-facing moderation: the reports queue + triage actions. Students
# create Reports (ReportCreateView); staff review and act on them here.

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from apps.accounts.permissions import IsStaff
from .models import Report

User = get_user_model()

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
