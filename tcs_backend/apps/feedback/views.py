# apps/feedback/views.py
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import Suggestion


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def submit_suggestion(request):
    """
    POST /api/feedback/suggest/
    Body: { "title": "...", "message": "...", "category": "feature|bug|..." }
    Tied to the authenticated user — not anonymous.
    """
    title    = request.data.get('title', '').strip()
    message  = request.data.get('message', '').strip()
    category = request.data.get('category', 'general')

    if not title:
        return Response({'error': 'Title is required.'}, status=400)
    if len(title) > 120:
        return Response({'error': 'Title max 120 characters.'}, status=400)
    if not message:
        return Response({'error': 'Message is required.'}, status=400)
    if len(message) < 10:
        return Response({'error': 'Message must be at least 10 characters.'}, status=400)

    valid_categories = [c[0] for c in Suggestion.CATEGORY_CHOICES]
    if category not in valid_categories:
        category = 'general'

    suggestion = Suggestion.objects.create(
        user=request.user,
        title=title,
        message=message,
        category=category,
    )

    return Response({
        'success':    True,
        'id':         str(suggestion.id),
        'message':    'Your suggestion has been submitted. Thank you! 🙏',
        'category':   suggestion.category,
        'created_at': suggestion.created_at.isoformat(),
    }, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_suggestions(request):
    """GET /api/feedback/mine/ — returns the user's own submissions."""
    suggestions = Suggestion.objects.filter(user=request.user)
    return Response([
        {
            'id':         str(s.id),
            'category':   s.category,
            'title':      s.title,
            'message':    s.message,
            'status':     s.status,
            'admin_note': s.admin_note,
            'created_at': s.created_at.isoformat(),
        }
        for s in suggestions
    ])