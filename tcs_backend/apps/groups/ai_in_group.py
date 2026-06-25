"""
apps/groups/ai_in_group.py

Dale-in-study-group AI engine — the groups-app twin of
apps.chat.ai_in_chat.summon_dale_in_room.

Study groups don't use chat Rooms/Messages; their conversation lives in
posts.Post rows tied to a group (post_type="post"). So Dale's reply here is
persisted as a Post authored by the shared Dale bot user with is_ai=True
(the frontend renders any is_ai post as a Dale bubble), exactly mirroring how
is_ai Messages work in chat rooms.

Reuses the same Dale bot account, the same GEMINI_API_KEY and the same
apps.ai.views one-shot helpers as the chat engine.
"""

import os
import logging

from apps.posts.models import Post
# Reuse the exact same bot user + Gemini config the chat engine uses.
from apps.chat.ai_in_chat import AIError, get_or_create_dale_user

logger = logging.getLogger(__name__)

DALE_GROUP_SYSTEM_PROMPT = (
    "You are Dale, a friendly AI study buddy living inside a TCS study group. "
    "You can read the recent group conversation (who said what, in order) and "
    "your job is to genuinely help the group study: answer questions, explain "
    "tough concepts simply, summarise what's being discussed, suggest how to "
    "tackle a problem, quiz them, or help them plan a session. Keep replies "
    "short — 1 to 4 short paragraphs. Be warm, encouraging and motivating, like "
    "a helpful member of the study group. When it makes sense, end by offering "
    "a next step (e.g. 'Want me to make a quick quiz on this?'). If the group "
    "chat is empty, introduce yourself briefly and ask what they're studying."
)


def _author_label(p):
    if getattr(p, "is_ai", False):
        return "Dale"
    a = p.author
    if not a:
        return "Student"
    return (getattr(a, "preferred_name", "") or getattr(a, "display_name", "")
            or getattr(a, "name", "") or "Student")


def summon_dale_in_group(group, asker, asker_message=None):
    """Gather the last ~20 group posts, ask Gemini, persist Dale's reply as an
    is_ai Post in the group, and return it. Raises AIError on failure.

    If `asker_message` is given it's appended as the latest user turn so Dale
    answers it directly; otherwise Dale summarises / offers help.
    """
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        raise AIError("AI service not configured. Try again later.")

    recent = (Post.objects
                  .filter(group=group, post_type="post", is_flagged=False)
                  .select_related("author")
                  .order_by("-created_at")[:20])
    recent = list(reversed(list(recent)))

    history = []
    for p in recent:
        body = (p.content or "").strip() or "(empty)"
        history.append({
            "role":    "model" if getattr(p, "is_ai", False) else "user",
            "content": f"{_author_label(p)}: {body}",
        })

    if asker_message:
        asker_name = (getattr(asker, "preferred_name", "") or
                      getattr(asker, "display_name", "") or
                      getattr(asker, "name", "") or "Student")
        history.append({"role": "user",
                        "content": f"{asker_name}: {asker_message}"})

    if not history:
        history.append({"role": "user",
                        "content": "(The group chat just started. No messages yet.)"})

    if asker_message:
        user_prompt = (
            "The last line above is a question or request directed at you. "
            "Respond to it directly and helpfully, using the rest of the "
            "conversation as context."
        )
    else:
        user_prompt = (
            "Read the conversation above and offer help. If there's a clear "
            "topic, give a tight summary and ask how you can help them study "
            "it. If it's casual or empty, introduce yourself briefly."
        )

    try:
        from apps.ai.views import _build_gemini_payload, _call_gemini_oneshot
        payload = _build_gemini_payload(
            DALE_GROUP_SYSTEM_PROMPT, history, user_prompt)
        ai_text = _call_gemini_oneshot(payload, api_key)
    except Exception as e:
        logger.exception("Gemini call failed in summon_dale_in_group")
        raise AIError(f"Dale couldn't respond right now: {e}")

    if not ai_text or not ai_text.strip():
        ai_text = ("Hey! I'm Dale \U0001F44B  What are you all studying? I can "
                   "explain things, summarise the chat, or make a quick quiz.")

    dale = get_or_create_dale_user()
    post = Post.objects.create(
        author=dale,
        group=group,
        post_type="post",
        visibility="public",
        content=ai_text.strip(),
        is_ai=True,
    )
    return post
