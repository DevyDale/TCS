# apps/feedback/views.py
import logging

from django.contrib.auth import get_user_model
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Suggestion, Category

logger = logging.getLogger(__name__)
User = get_user_model()

_STAFF_ROLES = ("teaching_staff", "non_teaching_staff", "admin")


def _notify_staff_of_school_suggestion(student, suggestion):
    """In-app + push notify every staff member about a new school suggestion.

    Non-anonymous by design: the student's name is in the body and the staff
    reading page shows who sent it.
    """
    student_name = getattr(student, "display_name", "") or getattr(
        student, "name", "") or "A student"
    title = "New suggestion to the school \U0001F4DD"
    body  = f"{student_name}: {suggestion.title}"
    try:
        from apps.notifications.tasks import _create, _fcm_send
    except Exception:
        logger.exception("could not import notification helpers")
        return

    staff = User.objects.filter(role__in=_STAFF_ROLES, is_active=True)
    for s in staff:
        try:
            _create(str(s.id), str(student.id), "suggestion", title, body,
                    "suggestion", str(suggestion.id))
            _fcm_send(getattr(s, "fcm_token", "") or "", title, body,
                      {"type": "suggestion",
                       "suggestion_id": str(suggestion.id)})
        except Exception:
            logger.exception("failed to notify staff %s", getattr(s, "id", "?"))


# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

def _serialize_category(cat):
    """Compact dict representation used everywhere the frontend
    needs to render a category tile or pill."""
    if cat is None:
        return None
    return {
        'id':            str(cat.id),
        'key':           cat.key,
        'label':         cat.label,
        'emoji':         cat.emoji,
        'gradient_from': cat.gradient_from,
        'gradient_to':   cat.gradient_to,
        'sort_order':    cat.sort_order,
    }


# ─────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_categories(request):
    """
    GET /api/feedback/categories/

    Returns the list of active feedback categories so the frontend
    can render the picker tiles entirely from data — admins control
    the list from the Django admin.
    """
    cats = Category.objects.filter(is_active=True).order_by('sort_order', 'label')
    return Response([_serialize_category(c) for c in cats])


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def submit_suggestion(request):
    """
    POST /api/feedback/suggest/
    Body: { "title": "...", "message": "...", "category": "<key>" }

    `category` is now the slug-style key of a Category row (e.g. 'bug').
    Rejected if missing, unknown, or inactive — no silent fallback.
    """
    title    = request.data.get('title', '').strip()
    message  = request.data.get('message', '').strip()
    cat_key  = request.data.get('category', '').strip()

    # Category — required, must resolve to an active row.
    if not cat_key:
        return Response({'error': 'Please choose a category.'}, status=400)
    try:
        cat = Category.objects.get(key=cat_key, is_active=True)
    except Category.DoesNotExist:
        return Response({'error': 'Unknown category.'}, status=400)

    # Title.
    if not title:
        return Response({'error': 'Title is required.'}, status=400)
    if len(title) > 120:
        return Response({'error': 'Title max 120 characters.'}, status=400)

    # Message.
    if not message:
        return Response({'error': 'Message is required.'}, status=400)
    if len(message) < 10:
        return Response({'error': 'Message must be at least 10 characters.'}, status=400)

    suggestion = Suggestion.objects.create(
        user=request.user,
        title=title,
        message=message,
        category=cat,
    )

    # "To the School" suggestions are never anonymous and ping every staffer.
    if cat.key == "school":
        _notify_staff_of_school_suggestion(request.user, suggestion)

    return Response({
        'success':    True,
        'id':         str(suggestion.id),
        'message':    'Your suggestion has been submitted. Thank you! 🙏',
        'category':   _serialize_category(cat),
        'status':     suggestion.status,
        'title':      suggestion.title,
        'created_at': suggestion.created_at.isoformat(),
    }, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_suggestions(request):
    """
    GET /api/feedback/mine/

    Returns the requesting user's submission history with embedded
    category dicts (so the frontend can render emoji + colour without
    a second round trip).
    """
    qs = (Suggestion.objects
                    .select_related('category')
                    .filter(user=request.user))
    return Response([
        {
            'id':         str(s.id),
            'category':   _serialize_category(s.category),
            'title':      s.title,
            'message':    s.message,
            'status':     s.status,
            'admin_note': s.admin_note,
            'created_at': s.created_at.isoformat(),
        }
        for s in qs
    ])


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def school_suggestions(request):
    """
    GET /api/feedback/school/  (staff only)

    All "To the School" suggestions from students, newest first, with the
    sender's name (these are never anonymous) so staff can read and act on them.
    """
    if (getattr(request.user, "role", "") or "") not in _STAFF_ROLES:
        return Response({'error': 'Staff only.'}, status=403)

    qs = (Suggestion.objects
                    .select_related('category', 'user')
                    .filter(category__key='school')
                    .order_by('-created_at'))
    return Response([
        {
            'id':            str(s.id),
            'title':         s.title,
            'message':       s.message,
            'status':        s.status,
            'priority':      s.priority,
            'theme':         s.theme,
            'is_flagged':    s.is_flagged,
            'admin_note':    s.admin_note,
            'student_name':  getattr(s.user, 'display_name', '') or
                             getattr(s.user, 'name', '') or 'Student',
            'student_id':    getattr(s.user, 'user_id', ''),
            'avatar_url':    request.build_absolute_uri(s.user.avatar.url)
                             if getattr(s.user, 'avatar', None) else None,
            'created_at':    s.created_at.isoformat(),
        }
        for s in qs
    ])


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def staff_update_suggestion(request, pk):
    """PATCH /api/feedback/staff/<id>/  — status / priority / note / flag."""
    if (getattr(request.user, "role", "") or "") not in _STAFF_ROLES:
        return Response({'error': 'Staff only.'}, status=403)
    s = Suggestion.objects.filter(id=pk).first()
    if not s:
        return Response({'error': 'Not found.'}, status=404)
    d = request.data
    valid_status = {c[0] for c in Suggestion.STATUS_CHOICES}
    if 'status' in d and d['status'] in valid_status:
        s.status = d['status']
    if 'priority' in d:
        try:
            s.priority = max(0, min(100, int(d['priority'])))
        except (TypeError, ValueError):
            pass
    if 'admin_note' in d:
        s.admin_note = (d.get('admin_note') or '')[:2000]
    if 'is_flagged' in d:
        s.is_flagged = bool(d['is_flagged'])
    s.save()
    return Response({'id': str(s.id), 'status': s.status, 'priority': s.priority,
                     'admin_note': s.admin_note, 'is_flagged': s.is_flagged})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def staff_reply_suggestion(request, pk):
    """POST /api/feedback/staff/<id>/reply/  {message} — notify the student."""
    if (getattr(request.user, "role", "") or "") not in _STAFF_ROLES:
        return Response({'error': 'Staff only.'}, status=403)
    s = Suggestion.objects.filter(id=pk).select_related('user').first()
    if not s:
        return Response({'error': 'Not found.'}, status=404)
    msg = (request.data.get('message') or '').strip()
    if not msg:
        return Response({'error': 'A reply is required.'}, status=400)
    s.admin_note = msg[:2000]
    s.save(update_fields=['admin_note', 'updated_at'])
    try:
        from apps.notifications.tasks import _create
        _create(str(s.user_id), str(request.user.id), "feedback",
                "Reply to your suggestion", msg, "suggestion", str(s.id))
    except Exception:
        logger.exception("suggestion reply notify failed")
    return Response({'ok': True})