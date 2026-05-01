# apps/ai/views.py
#
# Groq-powered TCS AI Assistant
# Endpoint: POST /api/ai/chat/
# Streams response back to Flutter via Server-Sent Events

import json
import os
import time
from django.http import StreamingHttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.core.cache import cache
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
import urllib.request
import urllib.error

# ── TCS System Prompt ─────────────────────────────────────────
# This is what makes the assistant campus-specific.
# Edit the facts below to match your real campus info.

TCS_SYSTEM_PROMPT = """You are the TCS AI Assistant — a friendly, helpful campus guide for 
Taylors College Social (TCS), a student social and learning platform at Taylors College, Malaysia.

Your personality:
- Warm, encouraging, and supportive
- Casual but professional — like a helpful senior student
- Concise — keep replies under 150 words unless explaining something complex
- Use occasional relevant emojis but don't overdo it

What you know about TCS:
- TCS is a Flutter mobile app with: Feed (posts, announcements), Study Hub (groups, study buddies), 
  Arcade (7 games: Campus Craft, Quiz Battle, Ninja Tag, Sushi Rush, Battle Bots, Spirit Racers, Pool Royale),
  Chat (DMs, group chats, voice notes, GIFs), Events, and Profile
- Students earn XP and Tokens by playing arcade games and engaging with the app
- Study Buddy feature lets students find peers to study with
- Events include academic workshops, sports carnivals, club meetups

What you can help with:
- Study tips and explaining academic concepts
- Campus navigation and app features
- Exam preparation strategies
- Finding study groups and buddies
- Understanding course content
- Campus events and activities
- General wellbeing and student life advice

What you cannot do:
- Access real-time data, live timetables, or grades
- Make bookings or changes to the student's account
- Access personal student records

If asked something outside your knowledge, be honest and suggest they contact the college office.
Always respond in the same language the student uses."""

# ── Rate limiting constants ───────────────────────────────────
MAX_MESSAGES_PER_HOUR = 30  # per user
RATE_LIMIT_WINDOW     = 3600  # seconds


def _check_rate_limit(user_id: str) -> tuple[bool, int]:
    """Returns (allowed, messages_used_this_hour)."""
    key   = f"ai_rate_{user_id}"
    count = cache.get(key, 0)
    if count >= MAX_MESSAGES_PER_HOUR:
        return False, count
    cache.set(key, count + 1, RATE_LIMIT_WINDOW)
    return True, count + 1


def _call_groq_stream(messages: list, api_key: str):
    """Generator that yields SSE chunks from Groq streaming API."""
    url     = "https://api.groq.com/openai/v1/chat/completions"
    payload = json.dumps({
        "model":       "llama-3.3-70b-versatile",
        "messages":    messages,
        "max_tokens":  512,
        "temperature": 0.7,
        "stream":      True,
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type":  "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            for raw_line in resp:
                line = raw_line.decode("utf-8").strip()
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if data == "[DONE]":
                    yield "data: [DONE]\n\n"
                    return
                try:
                    chunk   = json.loads(data)
                    content = chunk["choices"][0]["delta"].get("content", "")
                    if content:
                        payload_out = json.dumps({"token": content})
                        yield f"data: {payload_out}\n\n"
                except (json.JSONDecodeError, KeyError, IndexError):
                    continue
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        try:
            err = json.loads(body)
            msg = err.get("error", {}).get("message", "Groq API error")
        except Exception:
            msg = f"HTTP {e.code}"
        yield f"data: {json.dumps({'error': msg})}\n\n"
    except urllib.error.URLError as e:
        yield f"data: {json.dumps({'error': 'Network error reaching Groq'})}\n\n"
    except Exception as e:
        yield f"data: {json.dumps({'error': str(e)})}\n\n"


def _call_groq_sync(messages: list, api_key: str) -> str:
    """Non-streaming Groq call — returns full text. Used as fallback."""
    url     = "https://api.groq.com/openai/v1/chat/completions"
    payload = json.dumps({
        "model":       "llama-3.3-70b-versatile",
        "messages":    messages,
        "max_tokens":  512,
        "temperature": 0.7,
        "stream":      False,
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type":  "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data["choices"][0]["message"]["content"]
    except Exception as e:
        return f"Sorry, I'm having trouble connecting right now. Please try again in a moment."


# ── Main endpoint ─────────────────────────────────────────────

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def ai_chat(request):
    """
    POST /api/ai/chat/
    Body: {
        "message": "user's message",
        "history": [{"role": "user"|"assistant", "content": "..."}],
        "stream": true|false  (optional, default true)
    }
    Returns: StreamingHttpResponse (SSE) if stream=true, else JsonResponse
    """
    api_key = os.environ.get("GROQ_API_KEY", "")
    if not api_key:
        return JsonResponse({"error": "AI service not configured."}, status=503)

    # Rate limit check
    allowed, used = _check_rate_limit(str(request.user.id))
    if not allowed:
        return JsonResponse({
            "error": f"You've reached the limit of {MAX_MESSAGES_PER_HOUR} messages per hour. Try again later.",
            "rate_limited": True,
        }, status=429)

    try:
        body    = json.loads(request.body)
        message = body.get("message", "").strip()
        history = body.get("history", [])
        stream  = body.get("stream", True)
    except (json.JSONDecodeError, AttributeError):
        return JsonResponse({"error": "Invalid request body."}, status=400)

    if not message:
        return JsonResponse({"error": "Message cannot be empty."}, status=400)

    if len(message) > 2000:
        return JsonResponse({"error": "Message too long (max 2000 characters)."}, status=400)

    # Build messages array
    # Keep last 10 exchanges (20 messages) to stay within context limits
    recent_history = history[-20:] if len(history) > 20 else history

    messages = [
        {"role": "system", "content": TCS_SYSTEM_PROMPT},
        *recent_history,
        {"role": "user", "content": message},
    ]

    # Add user context if available
    user = request.user
    if hasattr(user, "name") and user.name:
        messages[0]["content"] += f"\n\nThe student you are talking to is named {user.name}."
    if hasattr(user, "role") and user.role:
        messages[0]["content"] += f" They are a {user.role}."

    if stream:
        response = StreamingHttpResponse(
            _call_groq_stream(messages, api_key),
            content_type="text/event-stream",
        )
        response["Cache-Control"]               = "no-cache"
        response["X-Accel-Buffering"]           = "no"
        response["X-RateLimit-Used"]            = str(used)
        response["X-RateLimit-Max"]             = str(MAX_MESSAGES_PER_HOUR)
        response["Access-Control-Allow-Origin"] = "*"
        return response
    else:
        reply = _call_groq_sync(messages, api_key)
        return JsonResponse({
            "reply":              reply,
            "rate_limit_used":    used,
            "rate_limit_max":     MAX_MESSAGES_PER_HOUR,
        })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def ai_status(request):
    """GET /api/ai/status/ — check rate limit remaining."""
    key   = f"ai_rate_{request.user.id}"
    used  = cache.get(key, 0)
    return JsonResponse({
        "messages_used":      used,
        "messages_remaining": max(0, MAX_MESSAGES_PER_HOUR - used),
        "limit":              MAX_MESSAGES_PER_HOUR,
        "model":              "llama-3.3-70b-versatile",
        "provider":           "Groq",
    })
