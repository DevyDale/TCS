from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Block
from .serializers import (
    ReportCreateSerializer, BlockSerializer, BlockCreateSerializer,
)
from .notifications import notify_admin_new_report


class ReportCreateView(generics.CreateAPIView):
    """POST /api/moderation/reports/ — submit a report."""
    serializer_class   = ReportCreateSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        report = serializer.save()
        try:
            notify_admin_new_report(report)
        except Exception:
            pass


class BlockListCreateView(generics.ListCreateAPIView):
    """GET/POST /api/moderation/blocks/"""
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        return BlockCreateSerializer if self.request.method == "POST" else BlockSerializer

    def get_queryset(self):
        return Block.objects.filter(blocker=self.request.user).select_related("blocked")

    def create(self, request, *args, **kwargs):
        s = BlockCreateSerializer(data=request.data, context={"request": request})
        s.is_valid(raise_exception=True)
        block, _ = Block.objects.get_or_create(
            blocker=request.user,
            blocked=s.validated_data["blocked"],
            defaults={"reason": s.validated_data.get("reason", "")},
        )
        return Response(BlockSerializer(block).data, status=status.HTTP_201_CREATED)


class BlockDestroyView(APIView):
    """DELETE /api/moderation/blocks/<user_id>/ — unblock."""
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, user_id):
        # Accept either UUID or user_id string. Resolve to User first.
        from django.contrib.auth import get_user_model
        User = get_user_model()
        target = None
        try:
            target = User.objects.filter(pk=user_id).first()
        except (ValueError, Exception):
            pass
        if target is None:
            target = User.objects.filter(user_id=user_id).first()
        if target is None:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)
        deleted, _ = Block.objects.filter(
            blocker=request.user, blocked=target,
        ).delete()
        if deleted == 0:
            return Response({"detail": "Not blocked."}, status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)
