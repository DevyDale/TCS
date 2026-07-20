"""
apps/chat/ai_in_chat.py

The Dale-in-chat AI engine, shared by apps.chat.bubble_views.

Provides the names bubble_views imports:
  • AIError                  — raised when Dale can't produce a reply.
  • DALE_USER_ID             — stable identifier used in Dale API payloads.
  • get_or_create_dale_user  — the bot User added as a room member.
  • post_system_message      — write (+ broadcast) a system message to a room.
  • summon_dale_in_room       — gather recent context, ask Gemini, persist +
                                broadcast Dale's reply, return the Message.

Mirrors the working one-shot engine in apps.chat.ai_analyze: same
GEMINI_API_KEY, same apps.ai.views helpers, same Message creation and
channel-layer broadcast. Dale's messages are stored with sender=None +
is_ai=True (the frontend renders any is_ai message as a Dale bubble); the
bot User exists only so Dale can appear as a room member.
"""

import os
import logging
from datetime import date

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.contrib.auth import get_user_model

from .models import Message
from apps.ai import ai_router   # fast multi-provider lane (Groq → … → Gemini)

logger = logging.getLogger(__name__)

# Stable id surfaced in the API payloads bubble_views returns for Dale's
# messages. Also the user_id of the bot account created below.
DALE_USER_ID = "dale-ai-bot"

DALE_SYSTEM_PROMPT = (
    "You are Dale, a friendly AI assistant living inside a TCS chat. You can "
    "read the recent conversation (who said what, in order) and your job is to "
    "be genuinely useful: answer questions, summarise what's being discussed, "
    "suggest a reply, fix or rewrite a message, explain a tough concept, or "
    "help the group organise. Keep replies short — 1 to 4 short paragraphs. "
    "Be warm and natural, like a helpful participant in the chat. When it makes "
    "sense, end by offering a next step (e.g. 'Want me to summarise the rest?'). "
    "If the conversation is empty, introduce yourself briefly and ask how you "
    "can help."
)


class AIError(Exception):
    """Raised when Dale cannot produce a reply (misconfig / upstream failure)."""
    pass


def get_or_create_dale_user():
    """Return the shared 'Dale' bot User, creating it on first use.

    Used so Dale can be added as a RoomMember. The messages Dale posts use
    sender=None + is_ai=True (see summon_dale_in_room); this account only
    represents membership in the room.
    """
    User = get_user_model()
    try:
        return User.objects.get(user_id=DALE_USER_ID)
    except User.DoesNotExist:
        role = getattr(getattr(User, "Role", None), "VISITOR", "visitor")
        return User.objects.create_user(
            user_id=DALE_USER_ID,
            role=role,
            name="Dale",
            date_of_birth=date(2000, 1, 1),
            preferred_name="Dale",
        )


def _broadcast(room, msg, *, is_system):
    """Best-effort WS broadcast so connected members see the message live."""
    try:
        channel_layer = get_channel_layer()
        if not channel_layer:
            return
        async_to_sync(channel_layer.group_send)(
            f"room_{room.id}",
            {
                "type":          "chat.message",  # matches the consumer handler
                "id":            str(msg.id),
                "room_id":       str(room.id),
                "sender_id":     None,
                "sender_name":   "" if is_system else "Dale",
                "sender_avatar": "",
                "message_type":  "text",
                "text":          msg.text,
                "is_ai":         (not is_system),
                "is_system":     is_system,
                "created_at":    msg.created_at.isoformat(),
            },
        )
    except Exception:
        logger.exception("Channel-layer broadcast failed for message %s",
                         getattr(msg, "id", "?"))


def post_system_message(room, text):
    """Create (and broadcast) a system message in the room. Returns it."""
    msg = Message.objects.create(
        room=room,
        sender=None,
        message_type=Message.MsgType.TEXT,
        text=text,
        is_system=True,
    )
    _broadcast(room, msg, is_system=True)
    return msg


def _sender_label(m):
    if m.is_ai:
        return "Dale"
    s = m.sender
    if not s:
        return "Student"
    return (getattr(s, "preferred_name", "") or getattr(s, "name", "") or
            getattr(s, "username", "") or "Student")


def summon_dale_in_room(room, asker, asker_message=None):
    """Gather the last ~20 messages, ask Gemini, persist + broadcast Dale's
    reply, and return the created Message. Raises AIError on failure.

    If `asker_message` is given it's appended as the latest user turn so Dale
    answers it directly; otherwise Dale summarises / offers help.
    """
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key and not ai_router.available("chat"):
        raise AIError("AI service not configured. Try again later.")

    recent = (Message.objects
                     .filter(room=room, is_deleted=False)
                     .select_related("sender")
                     .order_by("-created_at")[:20])
    recent = list(reversed(list(recent)))

    history = []
    for m in recent:
        if m.is_system:
            continue
        body = (m.display_text or "").strip() or "(empty)"
        history.append({
            "role":    "model" if m.is_ai else "user",
            "content": f"{_sender_label(m)}: {body}",
        })

    if asker_message:
        asker_name = (getattr(asker, "preferred_name", "") or
                      getattr(asker, "name", "") or "Student")
        history.append({"role": "user",
                        "content": f"{asker_name}: {asker_message}"})

    if not history:
        history.append({"role": "user",
                        "content": "(The chat just started. No messages yet.)"})

    if asker_message:
        user_prompt = (
            "The last line above is a question or request directed at you. "
            "Respond to it directly and helpfully, using the rest of the "
            "conversation as context."
        )
    else:
        user_prompt = (
            "Read the conversation above and offer help. If there's a clear "
            "topic, give a tight summary and ask how you can help. If it's "
            "casual or empty, introduce yourself briefly."
        )

    ai_text = ""
    # Fast path: the shared multi-provider router. Chat lane is
    # Groq → Cerebras → SambaNova → Gemini; Groq/Cerebras reply in well under a
    # second, versus several for a direct Gemini call. Failover + circuit-
    # breaking are handled inside the router.
    if ai_router.available("chat"):
        messages = [{"role": "system", "content": DALE_SYSTEM_PROMPT}]
        for h in history:
            messages.append({
                "role":    "assistant" if h["role"] == "model" else "user",
                "content": h["content"],
            })
        messages.append({"role": "user", "content": user_prompt})
        try:
            result = ai_router.complete("chat", messages,
                                        max_tokens=500, temperature=0.7)
            ai_text = (result.get("text") or "").strip()
        except Exception:
            logger.exception("ai_router failed in summon_dale_in_room")

    # Last resort: direct Gemini one-shot (legacy path) if the router had no
    # providers or every one failed on this request.
    if not ai_text and api_key:
        try:
            from apps.ai.views import _build_gemini_payload, _call_gemini_oneshot
            payload = _build_gemini_payload(DALE_SYSTEM_PROMPT, history, user_prompt)
            ai_text = _call_gemini_oneshot(payload, api_key)
        except Exception as e:
            logger.exception("Gemini call failed in summon_dale_in_room")
            raise AIError(f"Dale couldn't respond right now: {e}")

    if not ai_text or not ai_text.strip():
        ai_text = ("Hey! I'm Dale \U0001F44B  How can I help with what you're "
                   "working on? I can summarise, answer questions, or help "
                   "tidy up a message.")

    msg = Message.objects.create(
        room=room,
        sender=None,
        message_type=Message.MsgType.TEXT,
        text=ai_text.strip(),
        is_ai=True,
    )
    _broadcast(room, msg, is_system=False)
    return msg
