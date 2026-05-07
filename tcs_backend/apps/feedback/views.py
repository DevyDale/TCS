# apps/feedback/views.py
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Suggestion, Category


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