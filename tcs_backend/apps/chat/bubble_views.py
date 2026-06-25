# apps/chat/bubble_views.py
#
# All new endpoints for:
#   • Chat Bubbles  — group rooms with public/private + about
#   • Invitations   — send / list / accept / decline
#   • Dale AI       — enable / disable / summon inside any room
#
# Wire these into apps/chat/urls.py (see urls_patch.md).

import logging

from django.contrib.auth import get_user_model
from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Room, RoomMember, Message, RoomInvite
from .ai_in_chat import (
    AIError,
    DALE_USER_ID,
    summon_dale_in_room,
    post_system_message,
    get_or_create_dale_user,
)

User = get_user_model()
logger = logging.getLogger(__name__)


# ─── Serializers (small, scoped to bubbles/invites) ──────────

class BubbleListSerializer(serializers.ModelSerializer):
    avatar_url    = serializers.SerializerMethodField()
    member_count  = serializers.SerializerMethodField()
    is_member     = serializers.SerializerMethodField()
    has_pending   = serializers.SerializerMethodField()  # pending invite for me?

    class Meta:
        model  = Room
        fields = [
            "id", "name", "about", "avatar_url",
            "is_public", "ai_enabled",
            "member_count", "is_member", "has_pending",
            "created_at", "updated_at",
        ]

    def get_avatar_url(self, obj):
        req = self.context.get("request")
        if obj.avatar:
            return req.build_absolute_uri(obj.avatar.url) if req else obj.avatar.url
        return None

    def get_member_count(self, obj):
        return obj.memberships.filter(is_banned=False).count()

    def _me(self):
        req = self.context.get("request")
        return getattr(req, "user", None)

    def get_is_member(self, obj):
        u = self._me()
        return bool(u and obj.memberships.filter(user=u, is_banned=False).exists())

    def get_has_pending(self, obj):
        u = self._me()
        return bool(u and obj.invites.filter(invitee=u, status="pending").exists())


class InviteSerializer(serializers.ModelSerializer):
    room_id        = serializers.CharField(source="room.id", read_only=True)
    room_name      = serializers.CharField(source="room.name", read_only=True)
    room_about     = serializers.CharField(source="room.about", read_only=True)
    room_is_public = serializers.BooleanField(source="room.is_public", read_only=True)
    inviter_name   = serializers.SerializerMethodField()
    inviter_avatar = serializers.SerializerMethodField()

    class Meta:
        model  = RoomInvite
        fields = [
            "id", "room_id", "room_name", "room_about", "room_is_public",
            "inviter_name", "inviter_avatar",
            "status", "message", "created_at", "responded_at",
        ]

    def get_inviter_name(self, obj):
        return obj.inviter.display_name if obj.inviter else "Someone"

    def get_inviter_avatar(self, obj):
        req = self.context.get("request")
        if obj.inviter and obj.inviter.avatar:
            return req.build_absolute_uri(obj.inviter.avatar.url) if req else obj.inviter.avatar.url
        return None


# ═══════════════════════════════════════════════════════════════
# CHAT BUBBLES
# ═══════════════════════════════════════════════════════════════

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def create_bubble(request):
    """
    POST /api/chat/bubbles/

    Body:
      {
        "name":       "Calc Study Squad",
        "about":      "Stuck on integrals? Drop in.",
        "is_public":  true,
        "member_ids": ["abc", "def"],   // optional initial invites
        "ai_enabled": false             // optional, default false
      }

    Behaviour:
      • Creator becomes admin + member immediately.
      • member_ids do NOT auto-join — they receive RoomInvites instead,
        so they can accept/decline.
    """
    name       = (request.data.get("name", "") or "").strip()
    about      = (request.data.get("about", "") or "").strip()
    is_public  = bool(request.data.get("is_public", False))
    ai_enabled = bool(request.data.get("ai_enabled", False))
    member_ids = request.data.get("member_ids", []) or []

    if not name:
        return Response({"error": "Bubble name is required."}, status=400)
    if len(name) > 100:
        return Response({"error": "Name must be under 100 characters."}, status=400)

    room = Room.objects.create(
        room_type   = Room.RoomType.GROUP,
        name        = name,
        about       = about,
        is_public   = is_public,
        ai_enabled  = ai_enabled,
        created_by  = request.user,
    )
    RoomMember.objects.create(room=room, user=request.user)
    room.admins.add(request.user)

    # Send invites to listed users (skip self + Dale + duplicates)
    invitees = (
        User.objects
        .filter(user_id__in=member_ids)
        .exclude(id=request.user.id)
        .exclude(user_id=DALE_USER_ID)
        .distinct()
    )
    invites_sent = 0
    for u in invitees:
        RoomInvite.objects.create(
            room=room, invitee=u, inviter=request.user,
            message=f"{request.user.display_name} invited you to {name}.",
        )
        invites_sent += 1

    # If AI was enabled at creation, drop the join notice.
    if ai_enabled:
        post_system_message(room, "🤖 Dale is in this chat. Anyone can ask Dale anything.")

    return Response({
        "bubble":       BubbleListSerializer(room, context={"request": request}).data,
        "invites_sent": invites_sent,
    }, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def discover_bubbles(request):
    """
    GET /api/chat/bubbles/discover/?q=...
    Lists PUBLIC bubbles, optionally filtered by name/about.
    Excludes bubbles the user is already in.
    """
    q = (request.query_params.get("q", "") or "").strip()
    qs = Room.objects.filter(
        room_type=Room.RoomType.GROUP, is_public=True, is_active=True,
    ).exclude(memberships__user=request.user)

    if q:
        qs = qs.filter(Q(name__icontains=q) | Q(about__icontains=q))

    qs = qs.order_by("-last_message_at", "-created_at")[:40]
    return Response(BubbleListSerializer(
        qs, many=True, context={"request": request}
    ).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def join_public_bubble(request, room_id):
    """
    POST /api/chat/bubbles/<id>/join/
    Used for PUBLIC bubbles only — direct join, no invite needed.
    """
    try:
        room = Room.objects.get(id=room_id)
    except Room.DoesNotExist:
        return Response({"error": "Bubble not found."}, status=404)
    if not room.is_public:
        return Response({"error": "This bubble is private — you need an invite."}, status=403)
    if room.memberships.filter(user=request.user).exists():
        return Response({"error": "Already a member."}, status=400)

    RoomMember.objects.create(room=room, user=request.user)
    post_system_message(room, f"{request.user.display_name} joined the bubble.")
    return Response(BubbleListSerializer(room, context={"request": request}).data)


# ═══════════════════════════════════════════════════════════════
# INVITES
# ═══════════════════════════════════════════════════════════════

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def invite_to_bubble(request, room_id):
    """
    POST /api/chat/bubbles/<id>/invite/
    Body: { "user_ids": ["...", "..."] }
    Only existing members of the bubble can invite others.
    """
    try:
        room = Room.objects.get(id=room_id, room_type=Room.RoomType.GROUP)
    except Room.DoesNotExist:
        return Response({"error": "Bubble not found."}, status=404)

    if not room.memberships.filter(user=request.user).exists():
        return Response({"error": "Only members can invite."}, status=403)

    user_ids = request.data.get("user_ids", []) or []
    if not isinstance(user_ids, list) or not user_ids:
        return Response({"error": "user_ids must be a non-empty list."}, status=400)

    invitees = (
        User.objects
        .filter(user_id__in=user_ids)
        .exclude(id=request.user.id)
        .exclude(user_id=DALE_USER_ID)
        .distinct()
    )

    sent, skipped = 0, 0
    for u in invitees:
        # Skip if already a member or has a pending invite
        if room.memberships.filter(user=u).exists():
            skipped += 1
            continue
        if room.invites.filter(invitee=u, status="pending").exists():
            skipped += 1
            continue
        RoomInvite.objects.create(
            room=room, invitee=u, inviter=request.user,
            message=f"{request.user.display_name} invited you to {room.name}.",
        )
        sent += 1

    return Response({"sent": sent, "skipped": skipped})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def my_invites(request):
    """GET /api/chat/invites/  — pending invites for the current user."""
    invites = (
        RoomInvite.objects
        .filter(invitee=request.user, status="pending")
        .select_related("room", "inviter")
    )
    return Response(InviteSerializer(invites, many=True, context={"request": request}).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def accept_invite(request, invite_id):
    """POST /api/chat/invites/<id>/accept/"""
    try:
        inv = RoomInvite.objects.select_related("room", "inviter").get(
            id=invite_id, invitee=request.user, status="pending",
        )
    except RoomInvite.DoesNotExist:
        return Response({"error": "Invite not found or already responded to."}, status=404)

    inv.status = "accepted"
    inv.responded_at = timezone.now()
    inv.save(update_fields=["status", "responded_at"])

    # Add as member if not already
    if not inv.room.memberships.filter(user=request.user).exists():
        RoomMember.objects.create(room=inv.room, user=request.user)

    # Notify the room with a system message
    post_system_message(
        inv.room,
        f"{request.user.display_name} joined the bubble.",
    )

    # Also DM the inviter so they get notified
    if inv.inviter:
        try:
            from .models import Room as RoomModel
            dm_room, _ = RoomModel.get_or_create_direct(inv.inviter, get_or_create_dale_user())
            # Post a system note in inviter's DM with Dale (non-intrusive)
            post_system_message(
                dm_room,
                f"✅ {request.user.display_name} accepted your invite to {inv.room.name}.",
            )
        except Exception:
            # Non-critical: continue even if the notification helper fails
            pass

    return Response({"success": True, "room_id": str(inv.room.id)})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def decline_invite(request, invite_id):
    """POST /api/chat/invites/<id>/decline/"""
    try:
        inv = RoomInvite.objects.select_related("room", "inviter").get(
            id=invite_id, invitee=request.user, status="pending",
        )
    except RoomInvite.DoesNotExist:
        return Response({"error": "Invite not found or already responded to."}, status=404)

    inv.status = "declined"
    inv.responded_at = timezone.now()
    inv.save(update_fields=["status", "responded_at"])

    # Notify the inviter quietly via their Dale DM
    if inv.inviter:
        try:
            from .models import Room as RoomModel
            dm_room, _ = RoomModel.get_or_create_direct(inv.inviter, get_or_create_dale_user())
            post_system_message(
                dm_room,
                f"❌ {request.user.display_name} declined your invite to {inv.room.name}.",
            )
        except Exception:
            pass

    return Response({"success": True})


# ═══════════════════════════════════════════════════════════════
# DALE AI INSIDE A ROOM
# ═══════════════════════════════════════════════════════════════

def _ensure_member(request, room_id):
    try:
        room = Room.objects.get(id=room_id)
    except Room.DoesNotExist:
        return None, Response({"error": "Room not found."}, status=404)
    if not room.memberships.filter(user=request.user).exists():
        return None, Response({"error": "Not a member of this room."}, status=403)
    return room, None


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def enable_ai_in_room(request, room_id):
    """
    POST /api/chat/rooms/<id>/ai/enable/

    Adds Dale to the room: flips ai_enabled, posts a "joined" system
    message, and immediately summons one context-aware reply so the
    invoker gets something to read.
    """
    room, err = _ensure_member(request, room_id)
    if err: return err

    # Make sure Dale is a member of the room (so message lookups for
    # the user list show Dale and the existing consumer broadcasts to
    # her connection if she's ever wired up to one).
    dale = get_or_create_dale_user()
    if not room.memberships.filter(user=dale).exists():
        RoomMember.objects.create(room=room, user=dale)

    if not room.ai_enabled:
        room.ai_enabled = True
        room.save(update_fields=["ai_enabled"])
        post_system_message(room, "🤖 Dale joined the chat. Anyone can ask Dale anything.")

    # First reply
    try:
        msg = summon_dale_in_room(room, request.user)
    except AIError as e:
        return Response({"error": str(e)}, status=429 if "limit" in str(e).lower() else 503)

    return Response({
        "ai_enabled": True,
        "message": {
            "id":           str(msg.id),
            "text":         msg.text,
            "is_ai":        True,
            "sender_id":    DALE_USER_ID,
            "sender_name":  "Dale",
            "created_at":   msg.created_at.isoformat(),
            "message_type": msg.message_type,
        },
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def disable_ai_in_room(request, room_id):
    """POST /api/chat/rooms/<id>/ai/disable/"""
    room, err = _ensure_member(request, room_id)
    if err: return err

    if room.ai_enabled:
        room.ai_enabled = False
        room.save(update_fields=["ai_enabled"])
        post_system_message(room, "🤖 Dale left the chat.")
    return Response({"ai_enabled": False})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def summon_dale(request, room_id):
    """
    POST /api/chat/rooms/<id>/ai/summon/
    Body (optional): { "message": "What's a good way to revise calculus?" }

    On-demand AI reply. If `message` is provided, it's appended to the
    context as the latest user turn so Dale answers it directly.
    """
    room, err = _ensure_member(request, room_id)
    if err: return err

    if not room.ai_enabled:
        return Response({"error": "Enable Dale in this room first."}, status=400)

    user_msg = (request.data.get("message", "") or "").strip()
    try:
        msg = summon_dale_in_room(room, request.user, asker_message=user_msg or None)
    except AIError as e:
        code = 429 if "limit" in str(e).lower() else 503
        return Response({"error": str(e)}, status=code)

    return Response({
        "message": {
            "id":           str(msg.id),
            "text":         msg.text,
            "is_ai":        True,
            "sender_id":    DALE_USER_ID,
            "sender_name":  "Dale",
            "created_at":   msg.created_at.isoformat(),
            "message_type": msg.message_type,
        },
    })

# ─────────────────────────────────────────────────────────────
# Share a quiz into a chat room (renders as a tappable quiz card)
# ─────────────────────────────────────────────────────────────
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def share_quiz_to_room(request, room_id):
    """POST /api/chat/rooms/<id>/share-quiz/
       body: {quiz_id, title, count, difficulty}

    Creates a normal text Message whose body carries a quiz marker
    ([[quiz|id|title|count|difficulty]]). The app renders any message with
    that marker as a tappable quiz card. Broadcasts live like a real message.
    """
    from asgiref.sync import async_to_sync
    from channels.layers import get_channel_layer

    try:
        room = Room.objects.get(id=room_id)
    except Room.DoesNotExist:
        return Response({"error": "Room not found."}, status=404)
    if not RoomMember.objects.filter(room=room, user=request.user).exists():
        return Response({"error": "You're not in this chat."}, status=403)

    quiz_id = str(request.data.get("quiz_id") or "").strip()
    if not quiz_id:
        return Response({"error": "quiz_id is required."}, status=400)
    title = (str(request.data.get("title") or "Quiz")
             .replace("|", "/").replace("]", ")"))[:120]
    count = str(request.data.get("count") or "")
    difficulty = str(request.data.get("difficulty") or "")

    marker = f"[[quiz|{quiz_id}|{title}|{count}|{difficulty}]]"
    preview = f"\U0001F4DD Shared a quiz: “{title}”"
    text = f"{preview}\n{marker}"

    msg = Message.objects.create(
        room=room, sender=request.user,
        message_type=Message.MsgType.TEXT, text=text,
    )
    Room.objects.filter(id=room.id).update(
        last_message_text=preview,
        last_message_at=timezone.now(),
        last_message_sender=request.user,
    )

    payload = {
        "id":           str(msg.id),
        "room_id":      str(msg.room_id),
        "sender_id":    request.user.user_id,
        "sender_name":  request.user.display_name,
        "message_type": "text",
        "text":         text,
        "media_url":    None,
        "reply_to":     None,
        "reactions":    [],
        "is_edited":    False,
        "is_deleted":   False,
        "is_ai":        False,
        "is_system":    False,
        "created_at":   msg.created_at.isoformat(),
    }
    try:
        layer = get_channel_layer()
        if layer:
            async_to_sync(layer.group_send)(
                f"room_{room.id}", {"type": "chat.message", "payload": payload})
            async_to_sync(layer.group_send)(
                f"chatlist_{room.id}",
                {"type": "list.new_message", "room_id": str(room.id),
                 "message": payload})
    except Exception:
        logger.exception("share_quiz broadcast failed")

    return Response(payload, status=201)
