# apps/wellbeing/views.py
#
# Wellbeing analytics for designated safeguarding staff. Aggregate dashboards
# are anonymous; only the urgent case queue reveals identity (you can't act on a
# self-harm flag without knowing who). Every case view/action is audited. The AI
# is a triage signal — every flag needs human review; immediate danger → a real
# crisis line, not in-app handling.

from datetime import timedelta

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import CaseAction, WellbeingCase, WellbeingSignal

User = get_user_model()


def _is_wellbeing_staff(u):
    # Tightened gate: designated safeguarding staff. MVP = admin / superuser.
    return bool(getattr(u, "is_superuser", False)) or \
        (getattr(u, "role", "") or "").lower() == "admin"


def _name(u):
    return (getattr(u, "display_name", "") or getattr(u, "name", "") or "Student")


def _range(request):
    r = request.query_params.get("range", "7d")
    days = {"7d": 7, "30d": 30, "90d": 90}.get(r, 7)
    return timezone.now() - timedelta(days=days)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def overview(request):
    """Anonymous, aggregate campus wellbeing breakdown."""
    if not _is_wellbeing_staff(request.user):
        return Response({"error": "Wellbeing staff only."}, status=403)
    since = _range(request)
    sigs = WellbeingSignal.objects.filter(created_at__gte=since)
    tiers = {"thriving": 0, "okay": 0, "struggling": 0, "at_risk": 0}
    theme_counts = {}
    students = set()
    for s in sigs.iterator():
        tiers[s.tier] = tiers.get(s.tier, 0) + 1
        students.add(s.student_id)
        for th in (s.themes or []):
            theme_counts[th] = theme_counts.get(th, 0) + 1
    themes = sorted(({"theme": k, "count": v} for k, v in theme_counts.items()),
                    key=lambda x: x["count"], reverse=True)
    total = sum(tiers.values())
    # simple wellbeing index: weighted average (lower = more distress)
    weights = {"thriving": 1.0, "okay": 0.7, "struggling": 0.4, "at_risk": 0.1}
    index = (sum(weights[k] * v for k, v in tiers.items()) / total) if total else None
    return Response({
        "tiers": tiers,
        "themes": themes,
        "help_seeking": len(students),   # students who engaged on a wellbeing topic
        "signals": total,
        "open_cases": WellbeingCase.objects.filter(
            status__in=["open", "acknowledged", "in_progress"]).count(),
        "wellbeing_index": round(index, 2) if index is not None else None,
    })


def _case_dict(c, full=False):
    d = {
        "id":          str(c.id),
        "student":     _name(c.student),
        "severity":    c.severity,
        "status":      c.status,
        "ai_reason":   c.ai_reason,
        "themes":      (c.signal.themes if c.signal_id else []),
        "snippet":     (c.signal.snippet if c.signal_id else ""),
        "assigned_to": _name(c.assigned_to) if c.assigned_to_id else None,
        "created_at":  c.created_at.isoformat(),
    }
    if full:
        d["actions"] = [{
            "actor": a.actor_name, "action": a.action, "note": a.note,
            "at": a.created_at.isoformat(),
        } for a in c.actions.all()]
    return d


_SEV_ORDER = {"critical": 0, "high": 1, "watch": 2}


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def cases(request):
    """Urgent triage queue — named, severity then recency. Open cases first."""
    if not _is_wellbeing_staff(request.user):
        return Response({"error": "Wellbeing staff only."}, status=403)
    qs = WellbeingCase.objects.select_related("student", "signal", "assigned_to")
    status_f = request.query_params.get("status")
    if status_f:
        qs = qs.filter(status=status_f)
    else:
        qs = qs.exclude(status__in=["resolved", "dismissed"])
    items = sorted(qs, key=lambda c: (_SEV_ORDER.get(c.severity, 9),
                                      -c.created_at.timestamp()))
    return Response({"results": [_case_dict(c) for c in items[:200]]})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def case_detail(request, pk):
    if not _is_wellbeing_staff(request.user):
        return Response({"error": "Wellbeing staff only."}, status=403)
    c = WellbeingCase.objects.filter(id=pk).first()
    if not c:
        return Response({"error": "Not found."}, status=404)
    # Viewing a case (with its snippet) is itself audited.
    CaseAction.objects.create(case=c, actor=request.user,
                              actor_name=_name(request.user), action="viewed")
    return Response(_case_dict(c, full=True))


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def case_action(request, pk):
    if not _is_wellbeing_staff(request.user):
        return Response({"error": "Wellbeing staff only."}, status=403)
    c = WellbeingCase.objects.filter(id=pk).first()
    if not c:
        return Response({"error": "Not found."}, status=404)
    action = (request.data.get("action") or "").strip()
    note = (request.data.get("note") or "").strip()
    mapping = {
        "acknowledge": "acknowledged", "assign": "in_progress",
        "escalate": "escalated", "resolve": "resolved", "dismiss": "dismissed",
    }
    if action not in mapping:
        return Response({"error": "Invalid action."}, status=400)
    if action == "dismiss" and not note:
        return Response({"error": "A reason is required to dismiss a flag."},
                        status=400)
    c.status = mapping[action]
    if action == "assign":
        c.assigned_to = request.user
    if action == "dismiss":
        c.dismiss_reason = note
    c.save()
    CaseAction.objects.create(case=c, actor=request.user,
                              actor_name=_name(request.user),
                              action=action, note=note)
    return Response(_case_dict(c, full=True))
