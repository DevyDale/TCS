import json
import urllib.request
import urllib.parse
from django.contrib.auth import get_user_model
from django.db.models import Q
from django.utils import timezone
from rest_framework import generics, serializers, status
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from django.conf import settings as django_settings

from .models import Room, RoomMember, Message, StickerPack, Sticker, ChatRequest, SavedMaterial
from apps.media.validators import validate_file

User = get_user_model()


# ── Serializers ───────────────────────────────────────────────

class MemberSerializer(serializers.ModelSerializer):
    user_id      = serializers.CharField(source="user.user_id")
    display_name = serializers.CharField(source="user.display_name")
    is_online    = serializers.BooleanField(source="user.is_online")
    avatar_url   = serializers.SerializerMethodField()

    class Meta:
        model  = RoomMember
        fields = ["user_id", "display_name", "is_online", "avatar_url",
                  "is_muted", "joined_at", "nickname"]

    def get_avatar_url(self, obj):
        req = self.context.get("request")
        if obj.user.avatar:
            return req.build_absolute_uri(obj.user.avatar.url) if req else obj.user.avatar.url
        return None


class RoomSerializer(serializers.ModelSerializer):
    members      = MemberSerializer(source="memberships", many=True, read_only=True)
    avatar_url   = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    member_count = serializers.SerializerMethodField()
    other_user   = serializers.SerializerMethodField()

    class Meta:
        model  = Room
        fields = ["id", "room_type", "name", "description", "avatar_url",
                  "members", "member_count", "unread_count", "other_user",
                  "last_message", "created_at", "updated_at"]

    def get_avatar_url(self, obj):
        req = self.context.get("request")
        if obj.avatar:
            return req.build_absolute_uri(obj.avatar.url) if req else obj.avatar.url
        return None

    def get_other_user(self, obj):
        """For direct/study_buddy rooms — the other person's info."""
        req = self.context.get("request")
        if not req or obj.room_type not in ("direct", "study_buddy"):
            return None
        other_member = obj.memberships.exclude(user=req.user).select_related("user").first()
        if not other_member:
            return None
        u = other_member.user
        return {
            "user_id":    u.user_id,
            "name":       u.display_name,
            "role":       u.role,
            "avatar_url": req.build_absolute_uri(u.avatar.url) if u.avatar else None,
            "is_online":  u.is_online,
        }

    def get_unread_count(self, obj):
        user = self.context.get("request") and self.context["request"].user
        if not user or not user.is_authenticated:
            return 0
        try:
            m = obj.memberships.get(user=user)
            if m.last_read_message:
                return obj.messages.filter(
                    created_at__gt=m.last_read_message.created_at
                ).exclude(sender=user).count()
            return obj.messages.exclude(sender=user).count()
        except RoomMember.DoesNotExist:
            return 0

    def get_last_message(self, obj):
        msg = obj.messages.filter(is_deleted=False).last()
        if msg:
            return {
                "id":           str(msg.id),
                "text":         msg.display_text,
                "message_type": msg.message_type,
                "sender_name":  msg.sender.display_name if msg.sender else "",
                "created_at":   msg.created_at.isoformat(),
            }
        return None

    def get_member_count(self, obj):
        return obj.memberships.count()


class ChatRequestSerializer(serializers.ModelSerializer):
    sender_name   = serializers.CharField(source="sender.display_name", read_only=True)
    sender_avatar = serializers.SerializerMethodField()
    sender_role   = serializers.CharField(source="sender.role", read_only=True)
    sender_user_id = serializers.CharField(source="sender.user_id", read_only=True)

    class Meta:
        model  = ChatRequest
        fields = ["id", "sender_user_id", "sender_name", "sender_avatar",
                  "sender_role", "message", "status", "created_at"]

    def get_sender_avatar(self, obj):
        req = self.context.get("request")
        if obj.sender.avatar:
            return req.build_absolute_uri(obj.sender.avatar.url) if req else obj.sender.avatar.url
        return None


class SavedMaterialSerializer(serializers.ModelSerializer):
    class Meta:
        model  = SavedMaterial
        fields = ["id", "title", "file_url", "file_name", "file_type", "created_at"]


class StickerSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model  = Sticker
        fields = ["id", "name", "image_url", "is_animated", "sort_order"]

    def get_image_url(self, obj):
        req = self.context.get("request")
        if obj.image:
            return req.build_absolute_uri(obj.image.url) if req else obj.image.url
        return None


class StickerPackSerializer(serializers.ModelSerializer):
    stickers      = StickerSerializer(many=True, read_only=True)
    thumbnail_url = serializers.SerializerMethodField()

    class Meta:
        model  = StickerPack
        fields = ["id", "name", "thumbnail_url", "is_free", "token_cost", "stickers"]

    def get_thumbnail_url(self, obj):
        req = self.context.get("request")
        if obj.thumbnail:
            return req.build_absolute_uri(obj.thumbnail.url) if req else obj.thumbnail.url
        return None


# ── Room views ────────────────────────────────────────────────

class RoomListCreateView(generics.GenericAPIView):
    serializer_class = RoomSerializer

    def get(self, request):
        # Only direct + study_buddy + group rooms (no study group chats here)
        rooms = (Room.objects.filter(members=request.user, is_active=True)
                             .exclude(room_type="channel")
                             .prefetch_related("memberships__user")
                             .order_by("-last_message_at", "-created_at"))
        return Response(RoomSerializer(rooms, many=True, context={"request": request}).data)

    def post(self, request):
        room_type  = request.data.get("room_type", "group")
        member_ids = request.data.get("member_ids", [])
        name       = request.data.get("name", "")
        desc       = request.data.get("description", "")

        if room_type == "direct":
            if len(member_ids) != 1:
                return Response({"error": "Direct rooms need exactly one other user."}, status=400)
            try:
                other = User.objects.get(user_id=member_ids[0])
            except User.DoesNotExist:
                return Response({"error": "User not found."}, status=404)
            room, _ = Room.get_or_create_direct(request.user, other)
            return Response(RoomSerializer(room, context={"request": request}).data)

        # Group room
        members = list(User.objects.filter(user_id__in=member_ids))
        room    = Room.objects.create(room_type="group", name=name,
                                      description=desc, created_by=request.user)
        all_members = set(members) | {request.user}
        RoomMember.objects.bulk_create([RoomMember(room=room, user=u) for u in all_members])
        room.admins.add(request.user)
        return Response(RoomSerializer(room, context={"request": request}).data,
                        status=status.HTTP_201_CREATED)


class RoomDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = RoomSerializer

    def get_queryset(self):
        return Room.objects.filter(members=self.request.user)

    def get_object(self):
        return self.get_queryset().get(id=self.kwargs["room_id"])

    def destroy(self, request, *args, **kwargs):
        room = self.get_object()
        if room.created_by != request.user:
            return Response({"error": "Only creator can delete."}, status=403)
        room.is_active = False
        room.save(update_fields=["is_active"])
        return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
def start_dm(request):
    """POST /api/chat/dm/start/ — { user_id: "..." } Opens a DM directly."""
    uid = request.data.get("user_id", "")
    try:
        other = User.objects.get(user_id=uid)
    except User.DoesNotExist:
        return Response({"error": "User not found."}, status=404)
    room, _ = Room.get_or_create_direct(request.user, other)
    return Response(RoomSerializer(room, context={"request": request}).data)


@api_view(["GET"])
def search_chats(request):
    """GET /api/chat/dm/search/?q=... — search users (in rooms or globally)."""
    q = request.query_params.get("q", "").strip()
    if len(q) < 1:
        return Response({"results": []})

    # Search all users
    users = User.objects.filter(
        Q(name__icontains=q) | Q(preferred_name__icontains=q) | Q(user_id__icontains=q)
    ).exclude(id=request.user.id)[:20]

    following_ids = set(request.user.following.values_list("id", flat=True))
    followers_ids = set(request.user.followers.values_list("id", flat=True))

    results = []
    for u in users:
        is_connected = u.id in following_ids or u.id in followers_ids
        # Check if a room already exists
        room = Room.objects.filter(
            members=request.user, room_type="direct"
        ).filter(members=u).first()

        results.append({
            "user_id":      u.user_id,
            "name":         u.display_name,
            "role":         u.role,
            "avatar_url":   request.build_absolute_uri(u.avatar.url) if u.avatar else None,
            "is_online":    u.is_online,
            "is_connected": is_connected,
            "room_id":      str(room.id) if room else None,
        })

    return Response({"results": results})


@api_view(["GET"])
def message_history(request, room_id):
    if not RoomMember.objects.filter(room_id=room_id, user=request.user).exists():
        return Response({"error": "Not a member."}, status=403)
    before = request.query_params.get("before")
    qs = Message.objects.filter(room_id=room_id).select_related("sender").order_by("-created_at")
    if before:
        try:
            pivot = Message.objects.get(id=before)
            qs    = qs.filter(created_at__lt=pivot.created_at)
        except Message.DoesNotExist:
            pass
    msgs = list(qs[:50])
    msgs.reverse()
    data = [
        {
            "id":           str(m.id),
            "sender_id":    m.sender.user_id if m.sender else None,
            "sender_name":  m.sender.display_name if m.sender else "",
            "sender_avatar": request.build_absolute_uri(m.sender.avatar.url)
                             if m.sender and m.sender.avatar else None,
            "message_type": m.message_type,
            "text":         m.text,
            "media_url":    request.build_absolute_uri(m.media.url) if m.media else m.media_url or None,
            "file_name":    m.file_name or None,
            "file_size":    m.file_size,
            "is_deleted":   m.is_deleted,
            "created_at":   m.created_at.isoformat(),
        }
        for m in msgs
    ]
    return Response({"results": data, "count": len(data)})


@api_view(["POST"])
def mark_room_read(request, room_id):
    last = Message.objects.filter(room_id=room_id).last()
    if last:
        RoomMember.objects.filter(room_id=room_id, user=request.user).update(
            last_read_message=last)
    return Response({"success": True})


# ── Chat Requests ─────────────────────────────────────────────

@api_view(["GET"])
def chat_requests_list(request):
    """GET /api/chat/requests/ — all pending requests received."""
    reqs = ChatRequest.objects.filter(receiver=request.user, status="pending")\
                              .select_related("sender")
    return Response(ChatRequestSerializer(reqs, many=True, context={"request": request}).data)


@api_view(["POST"])
def send_chat_request(request):
    """POST /api/chat/requests/send/ — { user_id, message? }"""
    uid = request.data.get("user_id", "")
    msg = request.data.get("message", "")
    try:
        receiver = User.objects.get(user_id=uid)
    except User.DoesNotExist:
        return Response({"error": "User not found."}, status=404)
    if receiver == request.user:
        return Response({"error": "Cannot send to yourself."}, status=400)

    req, created = ChatRequest.objects.get_or_create(
        sender=request.user, receiver=receiver,
        defaults={"message": msg}
    )
    if not created and req.status == "declined":
        req.status  = "pending"
        req.message = msg
        req.save(update_fields=["status", "message"])

    return Response({"success": True, "request_id": str(req.id)},
                    status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


@api_view(["POST"])
def accept_chat_request(request, req_id):
    """POST /api/chat/requests/<id>/accept/"""
    try:
        req = ChatRequest.objects.get(id=req_id, receiver=request.user, status="pending")
    except ChatRequest.DoesNotExist:
        return Response({"error": "Request not found."}, status=404)

    room, _ = Room.get_or_create_direct(request.user, req.sender)
    req.status = "accepted"
    req.room   = room
    req.save(update_fields=["status", "room"])
    return Response({
        "success": True,
        "room":    RoomSerializer(room, context={"request": request}).data,
    })


@api_view(["POST"])
def decline_chat_request(request, req_id):
    """POST /api/chat/requests/<id>/decline/"""
    try:
        req = ChatRequest.objects.get(id=req_id, receiver=request.user, status="pending")
    except ChatRequest.DoesNotExist:
        return Response({"error": "Request not found."}, status=404)
    req.delete()
    return Response({"success": True})


# ── Study Buddy Chat ──────────────────────────────────────────

@api_view(["GET"])
def study_buddy_list(request):
    """
    GET /api/chat/study-buddy/
    Returns the current user's existing study buddy chat rooms.
    Used by the Share sheet to populate share targets.
    """
    rooms = Room.objects.filter(
        members=request.user,
        room_type="study_buddy",
    ).order_by("-updated_at")[:20]
    return Response(RoomSerializer(rooms, many=True, context={"request": request}).data)


@api_view(["POST"])
def start_study_buddy_chat(request):
    """POST /api/chat/study-buddy/start/ — { user_id, subject? }"""
    uid     = request.data.get("user_id", "")
    subject = request.data.get("subject", "")
    try:
        other = User.objects.get(user_id=uid)
    except User.DoesNotExist:
        return Response({"error": "User not found."}, status=404)

    room, _ = Room.get_or_create_study_buddy(request.user, other, subject)
    return Response(RoomSerializer(room, context={"request": request}).data,
                    status=status.HTTP_201_CREATED)


# ── Saved Materials ───────────────────────────────────────────

@api_view(["GET"])
def saved_materials(request):
    """GET /api/chat/saved/"""
    items = SavedMaterial.objects.filter(user=request.user)
    return Response(SavedMaterialSerializer(items, many=True).data)


@api_view(["POST"])
def save_material(request):
    """POST /api/chat/saved/save/ — { message_id?, title, file_url, file_name, file_type }"""
    msg_id    = request.data.get("message_id")
    title     = request.data.get("title", "")
    file_url  = request.data.get("file_url", "")
    file_name = request.data.get("file_name", "")
    file_type = request.data.get("file_type", "")

    message = None
    if msg_id:
        try:
            message = Message.objects.get(id=msg_id)
            if not file_url:
                file_url = request.build_absolute_uri(message.media.url) if message.media else ""
            if not file_name:
                file_name = message.file_name
            if not file_type:
                file_type = message.message_type
            if not title:
                title = file_name or "Saved Material"
        except Message.DoesNotExist:
            pass

    item = SavedMaterial.objects.create(
        user=request.user, message=message,
        title=title, file_url=file_url, file_name=file_name, file_type=file_type,
    )
    return Response(SavedMaterialSerializer(item).data, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def delete_saved_material(request, material_id):
    try:
        item = SavedMaterial.objects.get(id=material_id, user=request.user)
        item.delete()
    except SavedMaterial.DoesNotExist:
        pass
    return Response({"success": True})


# ── Media upload ──────────────────────────────────────────────

@api_view(["POST"])
@parser_classes([MultiPartParser, FormParser])
def upload_chat_media(request):
    room_id = request.data.get("room_id")
    file    = request.FILES.get("file")

    if not room_id or not file:
        return Response({"error": "room_id and file required."}, status=400)
    if not RoomMember.objects.filter(room_id=room_id, user=request.user).exists():
        return Response({"error": "Not a member."}, status=403)

    try:
        validated = validate_file(file)
    except ValueError as e:
        return Response({"error": str(e)}, status=400)

    msg = Message.objects.create(
        room_id=room_id, sender=request.user,
        message_type=validated["message_type"],
        media=file,
        file_name=file.name,
        file_size=file.size,
    )
    Room.objects.filter(id=room_id).update(
        last_message_text=msg.display_text,
        last_message_at=timezone.now(),
        last_message_sender=request.user,
    )
    return Response({
        "message_id":   str(msg.id),
        "media_url":    request.build_absolute_uri(msg.media.url),
        "message_type": msg.message_type,
        "file_name":    msg.file_name,
        "file_size":    msg.file_size,
    }, status=status.HTTP_201_CREATED)


# ── GIF search ────────────────────────────────────────────────

@api_view(["GET"])
def gif_search(request):
    query     = request.query_params.get("q", "")
    limit     = min(int(request.query_params.get("limit", 20)), 50)
    tenor_key = getattr(django_settings, "TENOR_API_KEY", "")
    if not tenor_key:
        return Response({"results": [], "message": "TENOR_API_KEY not configured."})
    params = urllib.parse.urlencode({"q": query, "key": tenor_key, "limit": limit,
                                     "contentfilter": "medium", "media_filter": "minimal"})
    try:
        with urllib.request.urlopen(
                f"https://tenor.googleapis.com/v2/search?{params}", timeout=5) as r:
            data = json.loads(r.read())
        return Response({"results": [
            {"id": item["id"], "url": item["media_formats"]["gif"]["url"],
             "preview_url": item["media_formats"].get("tinygif", {}).get("url", "")}
            for item in data.get("results", [])
        ]})
    except Exception as e:
        return Response({"results": [], "error": str(e)}, status=500)


@api_view(["GET"])
def gif_trending(request):
    limit     = min(int(request.query_params.get("limit", 16)), 50)
    tenor_key = getattr(django_settings, "TENOR_API_KEY", "")
    if not tenor_key:
        return Response({"results": []})
    params = urllib.parse.urlencode({"key": tenor_key, "limit": limit,
                                     "contentfilter": "medium", "media_filter": "minimal"})
    try:
        with urllib.request.urlopen(
                f"https://tenor.googleapis.com/v2/featured?{params}", timeout=5) as r:
            data = json.loads(r.read())
        return Response({"results": [
            {"id": item["id"], "url": item["media_formats"]["gif"]["url"],
             "preview_url": item["media_formats"].get("tinygif", {}).get("url", "")}
            for item in data.get("results", [])
        ]})
    except Exception as e:
        return Response({"results": [], "error": str(e)}, status=500)


@api_view(["GET"])
def sticker_packs(request):
    packs = StickerPack.objects.prefetch_related("stickers").all()
    return Response(StickerPackSerializer(packs, many=True, context={"request": request}).data)