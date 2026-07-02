# apps/chat/ai_in_chat.py
#
# Dale AI inside chat rooms (Meta-AI style) — Gemini edition.
#
# Public functions kept identical to the previous Groq version:
#   • get_or_create_dale_user()
#   • summon_dale_in_room(room, asker, asker_message=None)
#   • post_system_message(room, text)
# So bubble_views.py is untouched.
#
# Required env var:
#   GEMINI_API_KEY   — get one at https://aistudio.google.com/app/apikey
#
# Optional env var:
#   GEMINI_MODEL     — default "gemini-2.0-flash". Other picks:
#                      "gemini-2.5-flash", "gemini-1.5-flash",
#                      "gemini-1.5-pro" (slower, costlier).

import json
import os
import urllib.error
import urllib.parse
import urllib.request

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.utils import timezone

from .models import Message, Room

User = get_user_model()

# ── Constants ─────────────────────────────────────────────────

DALE_USER_ID   = "dale_ai"
DALE_NAME      = "Dale"
CONTEXT_LIMIT  = 12        # last N non-deleted messages fed to the model
RATE_LIMIT_KEY = "ai_rate_chat_{user_id}"
RATE_MAX       = 30        # AI replies per user per hour across all rooms
RATE_WINDOW    = 3600

# gemini-2.0-flash has a free-tier quota of 0 on our key (429s); 2.5-flash is
# the model the rest of the stack uses and has quota.
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

CHAT_SYSTEM_PROMPT = """You are Dale, the TCS campus AI assistant.

You are participating as a third party in a chat conversation between students.
Read the recent messages and respond helpfully, briefly, and in a friendly tone.

Guidelines:
- Keep replies under 80 words unless the question genuinely needs more.
- The chat history you see uses "Name: message" prefixes so you know who said what.
  When you reply, do NOT prefix your own messages with "Dale:" — just write the reply.
- Address people by name when it's clear who you're replying to.
- Don't repeat what was already said.
- If the conversation isn't asking you anything, give a useful nudge or summary
  rather than narrating the chat back at them.
- Use light emojis sparingly.
- You can help with: studies, campus events, app features, productivity,
  language explanations, general knowledge.
- You cannot access timetables, grades, or anyone's private records.
"""


# ── Dale system user ─────────────────────────────────────────

def get_or_create_dale_user():
    """
    Lazily create the Dale system user. Defaults are conservative — if your
    User model has additional required fields, adjust the defaults dict.
    """
    dale = User.objects.filter(user_id=DALE_USER_ID).first()
    if dale:
        return dale

    defaults = {
        "user_id":      DALE_USER_ID,
        "display_name": DALE_NAME,
    }
    # Best-effort fill of commonly-required fields without crashing on
    # schemas that don't have them.
    for attr, value in (
        ("name",       DALE_NAME),
        ("email",      "dale@tcs.local"),
        ("username",   DALE_USER_ID),
        ("first_name", DALE_NAME),
        ("is_active",  True),
        ("is_online",  True),
        ("role",       "system"),
    ):
        if hasattr(User, attr) and not callable(getattr(User, attr, None)):
            defaults.setdefault(attr, value)

    dale = User.objects.create(**defaults)
    if hasattr(dale, "set_unusable_password"):
        dale.set_unusable_password()
        if "password" in [f.name for f in dale._meta.fields]:
            dale.save(update_fields=["password"])
    return dale


# ── Rate limiting (separate bucket from /ai/chat/) ───────────

def _check_rate_limit(user_id) -> tuple[bool, int]:
    key   = RATE_LIMIT_KEY.format(user_id=user_id)
    count = cache.get(key, 0)
    if count >= RATE_MAX:
        return False, count
    cache.set(key, count + 1, RATE_WINDOW)
    return True, count + 1


# ── Gemini call ──────────────────────────────────────────────

def _call_gemini(contents: list, system_text: str, api_key: str) -> str:
    """
    Send a non-streaming generateContent request to Gemini and return the
    plain-text reply. Returns a friendly fallback string on error so the
    chat never silently fails.
    """
    url = (
        "https://generativelanguage.googleapis.com/v1beta/"
        f"models/{GEMINI_MODEL}:generateContent?"
        f"key={urllib.parse.quote(api_key)}"
    )
    body = {
        "system_instruction": {
            "parts": [{"text": system_text}],
        },
        "contents": contents,
        "generationConfig": {
            "temperature":     0.7,
            "maxOutputTokens": 400,
            "topP":            0.95,
        },
        # Be a bit permissive — chat banter is not "harmful". Adjust if
        # your campus policy needs stricter filtering.
        "safetySettings": [
            {"category": "HARM_CATEGORY_HARASSMENT",        "threshold": "BLOCK_ONLY_HIGH"},
            {"category": "HARM_CATEGORY_HATE_SPEECH",       "threshold": "BLOCK_ONLY_HIGH"},
            {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
            {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_ONLY_HIGH"},
        ],
    }

    payload = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body_txt = e.read().decode("utf-8", errors="replace")
        try:
            err = json.loads(body_txt).get("error", {})
            msg = err.get("message", f"HTTP {e.code}")
        except Exception:
            msg = f"HTTP {e.code}"
        return f"(Dale tripped on a wire — {msg}.)"
    except urllib.error.URLError:
        return "(Dale couldn't reach the network just now. Try again in a moment.)"
    except Exception as e:
        return f"(Dale ran into an error: {e})"

    # Parse out the text. Gemini can return blocked/empty candidates if
    # safety filters trip — handle that gracefully.
    candidates = data.get("candidates") or []
    if not candidates:
        # Sometimes promptFeedback explains why
        feedback = data.get("promptFeedback", {})
        reason   = feedback.get("blockReason")
        if reason:
            return f"(Dale couldn't respond — content blocked: {reason}.)"
        return "(Dale didn't have a reply for that one.)"

    parts = (candidates[0].get("content") or {}).get("parts") or []
    text  = "".join(p.get("text", "") for p in parts).strip()
    if not text:
        return "(Dale didn't have a reply for that one.)"
    return text


# ── Building the prompt from room context ────────────────────

def _build_contents_from_room(room: Room, asker_message: str | None) -> list:
    """
    Convert the last N non-deleted messages into Gemini's `contents` shape:
        [{"role": "user"|"model", "parts": [{"text": "..."}]}, ...]

    Speakers are prefixed in the text so Dale can keep track of who's who:
        "Alice: hey, how do I revise calc?"
        "Bob: yeah I'm stuck too"

    Gemini requires alternating user/model turns, so consecutive same-role
    entries are merged into a single turn (joined with newlines).
    """
    qs = (
        Message.objects
        .filter(room=room, is_deleted=False, is_system=False)
        .select_related("sender")
        .order_by("-created_at")[:CONTEXT_LIMIT]
    )
    recent = list(qs)
    recent.reverse()

    raw: list[tuple[str, str]] = []   # (role, text)
    for m in recent:
        if m.is_ai:
            raw.append(("model", (m.text or "").strip() or "(empty)"))
            continue

        text = (m.text or "").strip()
        if not text:
            kind = m.message_type or "media"
            text = f"({kind} sent)"
        speaker = m.sender.display_name if m.sender else "Someone"
        raw.append(("user", f"{speaker}: {text}"))

    # Append the fresh asker prompt (e.g. from "Ask Dale" composer)
    if asker_message:
        asker_message = asker_message.strip()
        if asker_message:
            raw.append(("user", asker_message))

    # Merge consecutive same-role turns to satisfy Gemini's alternation rule.
    merged: list[tuple[str, str]] = []
    for role, text in raw:
        if merged and merged[-1][0] == role:
            merged[-1] = (role, merged[-1][1] + "\n" + text)
        else:
            merged.append((role, text))

    # Gemini requires the FIRST content to have role "user". If history starts
    # with a model turn (rare — would mean the very first message in the room
    # is from Dale), drop it.
    while merged and merged[0][0] != "user":
        merged.pop(0)

    return [
        {"role": role, "parts": [{"text": text}]}
        for role, text in merged
    ]


# ── Public API ────────────────────────────────────────────────

class AIError(Exception):
    pass


def summon_dale_in_room(room: Room, asker, asker_message: str | None = None) -> Message:
    """
    Generate a Dale reply for the given room and persist it as a Message.
    Returns the newly created Message instance.
    Raises AIError on rate-limit or missing API key.
    """
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        raise AIError("AI service not configured.")

    allowed, _ = _check_rate_limit(asker.id)
    if not allowed:
        raise AIError(f"You've reached the AI limit of {RATE_MAX} per hour.")

    dale     = get_or_create_dale_user()
    contents = _build_contents_from_room(room, asker_message)

    # If for some reason there's no user content (brand-new empty room with
    # no asker_message), prime the model with a friendly opener.
    if not contents:
        contents = [{
            "role":  "user",
            "parts": [{"text": "Say hi and offer help. Keep it short."}],
        }]

    reply = _call_gemini(contents, CHAT_SYSTEM_PROMPT, api_key)

    msg = Message.objects.create(
        room         = room,
        sender       = dale,
        message_type = Message.MsgType.TEXT,
        text         = reply,
        is_ai        = True,
    )
    Room.objects.filter(id=room.id).update(
        last_message_text   = reply[:500],
        last_message_at     = timezone.now(),
        last_message_sender = dale,
    )
    return msg


def post_system_message(room: Room, text: str) -> Message:
    """Drop a small system-style notice into the room (e.g. 'Dale joined')."""
    dale = get_or_create_dale_user()
    msg = Message.objects.create(
        room         = room,
        sender       = dale,
        message_type = Message.MsgType.TEXT,
        text         = text,
        is_ai        = True,
        is_system    = True,
    )
    Room.objects.filter(id=room.id).update(
        last_message_text   = text[:500],
        last_message_at     = timezone.now(),
        last_message_sender = dale,
    )
    return msg