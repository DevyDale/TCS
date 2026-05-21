from django.contrib.auth import get_user_model
from django.conf import settings
from django.core.mail import send_mail
from rest_framework import permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from .models import BlockedUser, Report
from .serializers import BlockedUserSerializer

User = get_user_model()


# ─────────────────────────────────────────────────────────────
# Developer notification (Apple G1.2: blocking/reporting must
# notify the developer of inappropriate content).
#
# The Django admin moderation queue is the primary surface. If
# MODERATION_EMAIL is set we also fire an email. Notification
# failures must never break the user's block/report action.
# ─────────────────────────────────────────────────────────────

def _notify_developer(report):
    email = getattr(settings, "MODERATION_EMAIL", "")
    if not email:
        return
    try:
        send_mail(
            subject=f"[TCS Moderation] {report.get_reason_display()} — {report.target_type}",
            message=(
                f"A new moderation report needs action within 24 hours.\n\n"
                f"Target:      {report.target_type} {report.target_id}\n"
                f"Offender:    {report.offender}\n"
                f"Reason:      {report.reason}\n"
                f"Detail:      {report.detail or '(none)'}\n"
                f"Reported by: {report.reporter}\n\n"
                f"Review: https://tcs-nsw.duckdns.org/admin/safety/report/{report.id}/change/"
            ),
            from_email=getattr(settings, "DEFAULT_FROM_EMAIL", email),
            recipient_list=[email],
            fail_silently=True,
        )
    except Exception:
        pass


def _resolve_offender(target_type, target_id):
    """Best-effort lookup of who authored the offending content."""
    try:
        if target_type == Report.Target.USER:
            return User.objects.filter(user_id=target_id).first()
        if target_type == Report.Target.POST:
            from apps.posts.models import Post
            p = Post.objects.filter(pk=target_id).select_related("author").first()
            return p.author if p else None
        if target_type == Report.Target.COMMENT:
            from apps.posts.models import Comment
            c = Comment.objects.filter(pk=target_id).select_related("author").first()
            return c.author if c else None
    except Exception:
        return None
    return None


def _flag_post(post_id):
    """Pull a reported post out of feeds immediately, pending review."""
    try:
        from apps.posts.models import Post
        Post.objects.filter(pk=post_id).update(is_flagged=True)
    except Exception:
        pass


# ─────────────────────────────────────────────────────────────
# BLOCK  /  UNBLOCK
# ─────────────────────────────────────────────────────────────

@api_view(["POST", "DELETE"])
@permission_classes([permissions.IsAuthenticated])
def block_user(request, user_id):
    """
    POST   /api/safety/block/<user_id>/   — block (optional body: {reason})
    DELETE /api/safety/block/<user_id>/   — unblock

    Blocking instantly hides both users from each other's feeds and
    opens a moderation report so the developer is notified.
    """
    if request.method == "DELETE":
        BlockedUser.objects.filter(
            blocker=request.user, blocked__user_id=user_id
        ).delete()
        return Response({"blocked": False})

    if request.user.user_id == user_id:
        return Response({"error": "You can't block yourself."}, status=400)

    try:
        target = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        return Response({"error": "User not found."}, status=404)

    _, created = BlockedUser.objects.get_or_create(
        blocker=request.user, blocked=target,
        defaults={"reason": request.data.get("reason", "")},
    )

    if created:
        report = Report.objects.create(
            reporter=request.user,
            target_type=Report.Target.USER,
            target_id=target.user_id,
            offender=target,
            reason=Report.Reason.HARASSMENT,
            detail=f"User blocked. Reason given: {request.data.get('reason') or '(none)'}",
        )
        _notify_developer(report)

    return Response({"blocked": True})


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def blocked_list(request):
    """GET /api/safety/blocks/ — the users I've blocked (for a settings screen)."""
    qs   = BlockedUser.objects.filter(blocker=request.user).select_related("blocked")
    data = BlockedUserSerializer(qs, many=True, context={"request": request}).data
    return Response({"results": data, "count": len(data)})


# ─────────────────────────────────────────────────────────────
# REPORT
# ─────────────────────────────────────────────────────────────

@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def report_content(request):
    """
    POST /api/safety/report/
    Body: {target_type: 'user'|'post'|'comment', target_id, reason, detail?}

    Opens a moderation report and notifies the developer. A reported
    post is flagged so it drops out of every feed immediately.
    """
    target_type = (request.data.get("target_type") or "").strip().lower()
    target_id   = (request.data.get("target_id") or "").strip()
    reason      = (request.data.get("reason") or "other").strip().lower()
    detail      = (request.data.get("detail") or "").strip()

    if target_type not in Report.Target.values:
        return Response({"error": "Invalid target_type."}, status=400)
    if not target_id:
        return Response({"error": "target_id is required."}, status=400)
    if reason not in Report.Reason.values:
        reason = Report.Reason.OTHER

    report = Report.objects.create(
        reporter=request.user,
        target_type=target_type,
        target_id=target_id,
        offender=_resolve_offender(target_type, target_id),
        reason=reason,
        detail=detail,
    )

    if target_type == Report.Target.POST:
        _flag_post(target_id)

    _notify_developer(report)
    return Response({"reported": True}, status=201)
