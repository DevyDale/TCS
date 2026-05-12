from rest_framework import generics, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from .models import Activity
from .serializers import ActivitySerializer


class ActivityListView(generics.ListAPIView):
    serializer_class   = ActivitySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (Activity.objects
                        .filter(user=self.request.user)
                        .select_related("actor"))


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def mark_all_read(request):
    n = Activity.objects.filter(user=request.user, is_read=False).update(is_read=True)
    return Response({"success": True, "marked": n})


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def unread_count(request):
    n = Activity.objects.filter(user=request.user, is_read=False).count()
    return Response({"unread": n})
