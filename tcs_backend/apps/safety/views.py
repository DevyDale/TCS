# apps/safety/views.py
#
# Emergency alerts (incl. evacuation). Posting is open to staff; evacuation
# type additionally requires a verified fire warden. Resolve = poster + admin;
# hard-delete = admin only (soft-delete, recoverable). Audience-filtered so a
# student never receives a staff-only alert.

import logging
import os

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import EmergencyAck, EmergencyAlert, EmergencyAudit, EmergencyUpdate

User = get_user_model()
logger = logging.getLogger(__name__)

_STAFF_ROLES = ("teaching_staff", "non_teaching_staff", "admin")


def _name(u):
    return (getattr(u, "display_name", "") or getattr(u, "name", "") or "Staff")


def _is_staff(u):
    return bool(getattr(u, "is_superuser", False)) or \
        (getattr(u, "role", "") or "").lower() in _STAFF_ROLES


def _is_admin(u):
    return bool(getattr(u, "is_superuser", False)) or \
        (getattr(u, "role", "") or "").lower() == "admin"


def _targets_user(alert, u):
    """Does this alert's audience include user u?"""
    if alert.audience == "everyone":
        return True
    if alert.audience == "staff":
        return _is_staff(u)
    if alert.audience == "students":
        return (getattr(u, "role", "") or "").lower() == "student"
    return False


def _audience_qs(audience):
    qs = User.objects.filter(is_active=True)
    if audience == "staff":
        qs = qs.filter(role__in=_STAFF_ROLES)
    elif audience == "students":
        qs = qs.filter(role="student")
    # Safety guard: when EMERGENCY_FANOUT_ONLY_USER is set (dev/testing), real
    # alerts only reach that one account — never the live cohort.
    only = os.environ.get("EMERGENCY_FANOUT_ONLY_USER", "").strip()
    if only:
        qs = qs.filter(user_id=only)
    return qs


def _audit(alert, actor, action):
    try:
        EmergencyAudit.objects.create(alert=alert, actor=actor,
                                      actor_name=_name(actor), action=action)
    except Exception:
        logger.exception("emergency audit failed")


def _alert_dict(a, user=None):
    d = {
        "id":          str(a.id),
        "type":        a.type,
        "severity":    a.severity,
        "audience":    a.audience,
        "title":       a.title,
        "message":     a.message,
        "instruction": a.instruction,
        "zone":        a.zone,
        "is_drill":    a.is_drill,
        "status":      a.status,
        "posted_by":   a.posted_by_name,
        "posted_at":   a.posted_at.isoformat(),
        "resolved_at": a.resolved_at.isoformat() if a.resolved_at else None,
        "ack_count":   a.acks.count(),
        "requires_checkin": a.requires_checkin,
    }
    if user is not None:
        d["acked"]      = a.acks.filter(user=user).exists()
        d["can_manage"] = (a.posted_by_id == user.id) or _is_admin(user)
    return d


def _fanout(alert):
    """High-priority FCM + in-app notification to the audience."""
    try:
        from apps.notifications.tasks import _create, _fcm_send_multi
    except Exception:
        logger.exception("emergency fanout import failed")
        return
    prefix = "DRILL — " if alert.is_drill else ""
    title = f"{prefix}{alert.get_severity_display()} · {alert.get_type_display()}"
    body = alert.title
    actor_id = str(alert.posted_by_id) if alert.posted_by_id else None
    tokens = []
    for u in _audience_qs(alert.audience).exclude(id=alert.posted_by_id).iterator():
        try:
            _create(str(u.id), actor_id, "emergency", title, body,
                    "emergency", str(alert.id))
            tok = getattr(u, "fcm_token", None)
            if tok:
                tokens.append(tok)
        except Exception:
            pass
    try:
        _fcm_send_multi(tokens, title, body, {
            "type": "emergency", "emergency_id": str(alert.id),
            "severity": alert.severity, "priority": "high"})
    except Exception:
        logger.exception("emergency fcm failed")


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def emergency_create(request):
    u = request.user
    if not _is_staff(u):
        return Response({"error": "Staff only."}, status=403)
    d = request.data
    atype    = (d.get("type") or "general").strip()
    audience = (d.get("audience") or "").strip()
    title    = (d.get("title") or "").strip()
    message  = (d.get("message") or "").strip()
    if audience not in ("staff", "students", "everyone"):
        return Response({"error": "Choose an audience."}, status=400)
    if not title or not message:
        return Response({"error": "Title and message are required."}, status=400)
    if atype == "evacuation" and not getattr(u, "is_fire_warden", False):
        return Response(
            {"error": "Only a verified fire warden can trigger an evacuation."},
            status=403)
    severity = (d.get("severity") or "high").strip()
    if severity not in ("info", "high", "critical"):
        severity = "high"

    a = EmergencyAlert.objects.create(
        type=atype, severity=severity, audience=audience,
        title=title[:120], message=message,
        instruction=(d.get("instruction") or "").strip()[:300],
        zone=(d.get("zone") or "").strip()[:80],
        is_drill=bool(d.get("is_drill")),
        posted_by=u, posted_by_name=_name(u))
    _audit(a, u, "post")
    _fanout(a)
    return Response(_alert_dict(a, u), status=201)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def emergency_active(request):
    """Active, non-deleted alerts that target this user."""
    u = request.user
    alerts = EmergencyAlert.objects.filter(status="active", is_deleted=False)
    out = [_alert_dict(a, u) for a in alerts if _targets_user(a, u)]
    return Response({"results": out})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def emergency_detail(request, pk):
    a = EmergencyAlert.objects.filter(id=pk, is_deleted=False).first()
    if not a:
        return Response({"error": "Not found."}, status=404)
    u = request.user
    if not (_targets_user(a, u) or _is_staff(u)):
        return Response({"error": "Not found."}, status=404)
    d = _alert_dict(a, u)
    d["updates"] = [{
        "author": up.author_name, "text": up.text,
        "created_at": up.created_at.isoformat(),
    } for up in a.updates.all()]
    return Response(d)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def emergency_update(request, pk):
    a = EmergencyAlert.objects.filter(id=pk, is_deleted=False).first()
    if not a:
        return Response({"error": "Not found."}, status=404)
    u = request.user
    if not ((a.posted_by_id == u.id) or _is_admin(u)):
        return Response({"error": "Only the poster or an admin can add updates."},
                        status=403)
    text = (request.data.get("text") or "").strip()
    if not text:
        return Response({"error": "Update text is required."}, status=400)
    EmergencyUpdate.objects.create(alert=a, author=u, author_name=_name(u), text=text)
    _audit(a, u, "update")
    return Response({"ok": True})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def emergency_resolve(request, pk):
    a = EmergencyAlert.objects.filter(id=pk, is_deleted=False).first()
    if not a:
        return Response({"error": "Not found."}, status=404)
    u = request.user
    if not ((a.posted_by_id == u.id) or _is_admin(u)):
        return Response({"error": "Only the poster or an admin can resolve this."},
                        status=403)
    a.status = "resolved"
    a.resolved_by = u
    a.resolved_at = timezone.now()
    a.save(update_fields=["status", "resolved_by", "resolved_at"])
    _audit(a, u, "resolve")
    # All-clear notification.
    try:
        from apps.notifications.tasks import _create, _fcm_send_multi
        title = "✅ All clear"
        body = f"{a.title} — safe to return."
        toks = []
        for usr in _audience_qs(a.audience).exclude(id=u.id).iterator():
            try:
                _create(str(usr.id), str(u.id), "emergency", title, body,
                        "emergency", str(a.id))
                t = getattr(usr, "fcm_token", None)
                if t:
                    toks.append(t)
            except Exception:
                pass
        _fcm_send_multi(toks, title, body,
                        {"type": "emergency_clear", "emergency_id": str(a.id)})
    except Exception:
        logger.exception("all-clear fanout failed")
    return Response({"ok": True})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def emergency_ack(request, pk):
    a = EmergencyAlert.objects.filter(id=pk, is_deleted=False).first()
    if not a:
        return Response({"error": "Not found."}, status=404)
    EmergencyAck.objects.get_or_create(
        alert=a, user=request.user,
        defaults={"user_name": _name(request.user)})
    return Response({"ok": True, "ack_count": a.acks.count()})


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def emergency_delete(request, pk):
    a = EmergencyAlert.objects.filter(id=pk).first()
    if not a:
        return Response({"error": "Not found."}, status=404)
    if not _is_admin(request.user):
        return Response({"error": "Only an admin can delete an emergency."},
                        status=403)
    a.is_deleted = True
    a.save(update_fields=["is_deleted"])
    _audit(a, request.user, "delete")
    return Response(status=204)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def emergency_history(request):
    if not _is_staff(request.user):
        return Response({"error": "Staff only."}, status=403)
    alerts = EmergencyAlert.objects.filter(is_deleted=False)[:100]
    return Response({"results": [_alert_dict(a, request.user) for a in alerts]})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def emergency_roster(request, pk):
    """Who has checked in safe vs not (evacuation roster). Staff only."""
    a = EmergencyAlert.objects.filter(id=pk, is_deleted=False).first()
    if not a:
        return Response({"error": "Not found."}, status=404)
    if not _is_staff(request.user):
        return Response({"error": "Staff only."}, status=403)
    safe_ids = set(str(uid) for uid in a.acks.values_list("user_id", flat=True))
    safe = [{"name": ack.user_name,
             "at": ack.acked_at.isoformat()} for ack in a.acks.select_related("user")]
    pending = []
    for usr in _audience_qs(a.audience):
        if str(usr.id) not in safe_ids:
            pending.append({"name": _name(usr)})
    return Response({
        "safe_count": len(safe), "pending_count": len(pending),
        "safe": safe, "pending": pending,
    })
