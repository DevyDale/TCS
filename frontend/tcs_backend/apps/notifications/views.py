from rest_framework import serializers, status
from rest_framework.decorators import api_view
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    actor_name   = serializers.CharField(source="actor.display_name",
                                         read_only=True, allow_null=True)
    actor_avatar = serializers.SerializerMethodField()

    class Meta:
        model  = Notification
        fields = ["id", "notif_type", "title", "body",
                  "actor_name", "actor_avatar",
                  "target_type", "target_id",
                  "is_read", "created_at"]

    def get_actor_avatar(self, obj):
        if obj.actor and obj.actor.avatar:
            req = self.context.get("request")
            return req.build_absolute_uri(obj.actor.avatar.url) if req else obj.actor.avatar.url
        return None


@api_view(["GET"])
def notification_list(request):
    unread_only = request.query_params.get("unread") == "true"
    qs = Notification.objects.filter(recipient=request.user).select_related("actor")
    if unread_only:
        qs = qs.filter(is_read=False)

    paginator = PageNumberPagination()
    paginator.page_size = 30
    page = paginator.paginate_queryset(qs, request)
    ser  = NotificationSerializer(page, many=True, context={"request": request})
    resp = paginator.get_paginated_response(ser.data)
    resp.data["unread_count"] = Notification.objects.filter(
        recipient=request.user, is_read=False).count()
    return resp


@api_view(["GET"])
def unread_count(request):
    count = Notification.objects.filter(recipient=request.user, is_read=False).count()
    return Response({"unread_count": count})


@api_view(["POST"])
def mark_read(request, notif_id):
    updated = Notification.objects.filter(id=notif_id, recipient=request.user).update(is_read=True)
    if not updated:
        return Response({"error": "Not found."}, status=404)
    return Response({"success": True})


@api_view(["POST"])
def mark_all_read(request):
    count = Notification.objects.filter(
        recipient=request.user, is_read=False).update(is_read=True)
    return Response({"success": True, "marked": count})


@api_view(["DELETE"])
def delete_notification(request, notif_id):
    Notification.objects.filter(id=notif_id, recipient=request.user).delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["DELETE"])
def clear_all(request):
    Notification.objects.filter(recipient=request.user).delete()
    return Response(status=status.HTTP_204_NO_CONTENT)
