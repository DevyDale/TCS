"""
Dale AI in chat rooms.

POST /api/chat/rooms/<room_id>/ai-analyze/  (auth required)

Pulls the last ~20 messages from the room, asks Gemini for a helpful
analysis + offer of assistance, then saves the response as a Message
row with is_ai=True. Returns the created message.

The new message also broadcasts via the channel layer so every member
of the room sees Dale's response in real-time.
"""

import os
import logging
import uuid

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Message, Room, RoomMember

logger = logging.getLogger(__name__)

DALE_SYSTEM_PROMPT = (
    "You are Dale, a friendly AI study assistant living inside a TCS student "
    "study group. You can read the group's recent conversation and your job "
    "is to be helpful: summarise what's being discussed, answer questions, "
    "suggest resources, or break down a tough concept. Keep replies to 2-4 "
    "short paragraphs maximum. Address the group directly (use 'everyone' "
    "or 'team', not individual names). Always end by asking how else you "
    "can help — e.g., 'Want me to dig deeper into any of this?' or 'Should "
    "I make a quick quiz on this?'. If the conversation is empty or off-topic, "
    "introduce yourself and ask what the group is studying today."
)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def ai_analyze_room(request, room_id):
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        return Response(
            {"error": "AI service not configured. Try again later."},
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    room = get_object_or_404(Room, id=room_id)

    # Must be a room member to summon Dale
    is_member = RoomMember.objects.filter(room=room, user=request.user).exists()
    if not is_member:
        return Response(
            {"error": "Only members can summon Dale in this group."},
            status=status.HTTP_403_FORBIDDEN,
        )

    # ── Gather last 20 messages ────────────────────────────────────
    recent = (Message.objects
                     .filter(room=room, is_deleted=False)
                     .select_related("sender")
                     .order_by("-created_at")[:20])
    recent = list(reversed(list(recent)))

    history = []
    for m in recent:
        if m.is_system:
            continue
        who = "Dale" if m.is_ai else (
            (getattr(m.sender, "first_name", "") or
             getattr(m.sender, "username", "") or
             "Student") if m.sender else "Student"
        )
        body = m.display_text or "(empty)"
        history.append({"role": "user" if not m.is_ai else "model",
                        "content": f"{who}: {body}"})

    if not history:
        history.append({
            "role": "user",
            "content": "(The group just started. No messages yet.)",
        })

    user_prompt = (
        "Analyse the conversation above and offer help. "
        "If there's a clear topic, give a tight summary and ask how to help. "
        "If it's casual chat or empty, introduce yourself."
    )

    # ── Call Gemini (reuse helpers from apps.ai.views) ─────────────
    try:
        from apps.ai.views import _build_gemini_payload, _call_gemini_oneshot
        payload   = _build_gemini_payload(DALE_SYSTEM_PROMPT, history, user_prompt)
        ai_text   = _call_gemini_oneshot(payload, api_key)
    except Exception as e:
        logger.exception("Gemini call failed in ai_analyze_room")
        return Response(
            {"error": f"Dale couldn't respond right now: {e}"},
            status=status.HTTP_502_BAD_GATEWAY,
        )

    if not ai_text or not ai_text.strip():
        ai_text = "Hey everyone! I'm Dale 👋  What are you studying today? I can summarise, quiz you, or help with tricky concepts."

    # ── Persist as a Message row (is_ai=True, sender=None) ────────
    msg = Message.objects.create(
        room         = room,
        sender       = None,
        message_type = Message.MsgType.TEXT,
        text         = ai_text.strip(),
        is_ai        = True,
    )

    # ── Broadcast over WebSocket so every member sees it ──────────
    try:
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                f"room_{room.id}",
                {
                    "type":  "chat.message",   # matches existing consumer handler
                    "id":             str(msg.id),
                    "room_id":        str(room.id),
                    "sender_id":      None,
                    "sender_name":    "Dale",
                    "sender_avatar":  "",
                    "message_type":   "text",
                    "text":           msg.text,
                    "is_ai":          True,
                    "is_system":      False,
                    "created_at":     msg.created_at.isoformat(),
                },
            )
    except Exception:
        logger.exception("Channel-layer broadcast failed for Dale message %s", msg.id)

    return Response({
        "id":           str(msg.id),
        "room_id":      str(room.id),
        "sender_id":    None,
        "sender_name":  "Dale",
        "message_type": "text",
        "text":         msg.text,
        "is_ai":        True,
        "is_system":    False,
        "created_at":   msg.created_at.isoformat(),
    }, status=status.HTTP_201_CREATED)
