# apps/scam/views.py
#
# Scam intel: students report scams + read campus alerts; staff triage reports
# and publish alerts (fanned out to students). The message-checker itself is
# the existing /api/ai/scam-check/ (Dale) — not duplicated here.

import logging
import os

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import ScamAlert, ScamBlocklist, ScamReport

User = get_user_model()
logger = logging.getLogger(__name__)

_STAFF_ROLES = ("teaching_staff", "non_teaching_staff", "admin")


def _name(u):
    return (getattr(u, "display_name", "") or getattr(u, "name", "") or "")


def _is_staff(u):
    return bool(getattr(u, "is_superuser", False)) or \
        (getattr(u, "role", "") or "").lower() in _STAFF_ROLES


def _report_dict(r):
    return {
        "id":         str(r.id),
        "student":    r.student_name or "Student",
        "scam_type":  r.scam_type,
        "content":    r.content,
        "contact":    r.contact,
        "was_victim": r.was_victim,
        "status":     r.status,
        "created_at": r.created_at.isoformat(),
    }


def _alert_dict(a):
    return {
        "id":        str(a.id),
        "title":     a.title,
        "body":      a.body,
        "scam_type": a.scam_type,
        "posted_by": a.posted_by_name,
        "posted_at": a.posted_at.isoformat(),
    }


# ── Student ───────────────────────────────────────────────────
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def scam_report(request):
    content = (request.data.get("content") or "").strip()
    if not content:
        return Response({"error": "Describe or paste the scam."}, status=400)
    r = ScamReport.objects.create(
        student=request.user, student_name=_name(request.user),
        scam_type=(request.data.get("scam_type") or "other").strip()[:20],
        content=content,
        contact=(request.data.get("contact") or "").strip()[:200],
        was_victim=bool(request.data.get("was_victim")))
    return Response(_report_dict(r), status=201)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def scam_alerts(request):
    """Active campus alerts for the student Detector feed."""
    now = timezone.now()
    qs = ScamAlert.objects.filter(is_active=True)
    out = [_alert_dict(a) for a in qs
           if a.expires_at is None or a.expires_at > now]
    return Response({"results": out})


# ── Staff ─────────────────────────────────────────────────────
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def staff_reports(request):
    if not _is_staff(request.user):
        return Response({"error": "Staff only."}, status=403)
    qs = ScamReport.objects.all()
    status_f = request.query_params.get("status")
    if status_f:
        qs = qs.filter(status=status_f)
    return Response({"results": [_report_dict(r) for r in qs[:200]]})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def staff_report_action(request, pk):
    if not _is_staff(request.user):
        return Response({"error": "Staff only."}, status=403)
    r = ScamReport.objects.filter(id=pk).first()
    if not r:
        return Response({"error": "Not found."}, status=404)
    status_v = (request.data.get("status") or "").strip()
    if status_v not in ("new", "reviewing", "confirmed", "dismissed"):
        return Response({"error": "Invalid status."}, status=400)
    r.status = status_v
    r.save(update_fields=["status"])
    return Response(_report_dict(r))


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def staff_alerts(request):
    if not _is_staff(request.user):
        return Response({"error": "Staff only."}, status=403)
    if request.method == "GET":
        return Response({"results": [_alert_dict(a)
                                     for a in ScamAlert.objects.all()[:100]]})
    title = (request.data.get("title") or "").strip()
    body = (request.data.get("body") or "").strip()
    if not title or not body:
        return Response({"error": "Title and body are required."}, status=400)
    a = ScamAlert.objects.create(
        title=title[:120], body=body,
        scam_type=(request.data.get("scam_type") or "other").strip()[:20],
        posted_by=request.user, posted_by_name=_name(request.user))
    _fanout_alert(a)
    return Response(_alert_dict(a), status=201)


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def staff_blocklist(request):
    if not _is_staff(request.user):
        return Response({"error": "Staff only."}, status=403)
    if request.method == "GET":
        return Response({"results": [{
            "id": str(b.id), "value": b.value, "kind": b.kind, "note": b.note,
        } for b in ScamBlocklist.objects.all()[:300]]})
    value = (request.data.get("value") or "").strip()
    if not value:
        return Response({"error": "Value is required."}, status=400)
    b, _ = ScamBlocklist.objects.get_or_create(
        value=value[:200],
        defaults={"kind": (request.data.get("kind") or "url").strip()[:12],
                  "note": (request.data.get("note") or "").strip()[:200],
                  "added_by": request.user})
    return Response({"id": str(b.id), "value": b.value, "kind": b.kind}, status=201)


def _fanout_alert(a):
    """Push a campus scam alert to all students (guarded for dev testing)."""
    try:
        from apps.notifications.tasks import _create, _fcm_send_multi
    except Exception:
        return
    qs = User.objects.filter(is_active=True, role="student")
    only = os.environ.get("SCAM_FANOUT_ONLY_USER", "").strip()
    if only:
        qs = qs.filter(user_id=only)
    title = "⚠️ Scam alert"
    body = a.title
    toks = []
    for u in qs.iterator():
        try:
            _create(str(u.id), str(a.posted_by_id) if a.posted_by_id else None,
                    "scam_alert", title, body, "scam_alert", str(a.id))
            t = getattr(u, "fcm_token", None)
            if t:
                toks.append(t)
        except Exception:
            pass
    try:
        _fcm_send_multi(toks, title, body,
                        {"type": "scam_alert", "alert_id": str(a.id)})
    except Exception:
        logger.exception("scam alert fcm failed")
