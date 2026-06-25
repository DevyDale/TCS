# apps/ai/views.py
#
# TCS AI tools — Google Gemini 2.5 Flash + Pollinations FLUX
#
# Endpoints:
#   POST   /api/ai/chat/                              — general assistant (SSE)
#   POST   /api/ai/code/                              — code generator    (SSE)
#   GET    /api/ai/status/                            — rate-limit usage
#
#   GET    /api/ai/companions/                        — list personas
#   GET    /api/ai/companions/<uuid>/                 — companion detail
#   POST   /api/ai/companions/<uuid>/chat/            — chat with persona (SSE)
#   GET    /api/ai/companions/<uuid>/conversations/   — user's threads
#
#   GET    /api/ai/conversations/<uuid>/messages/     — load thread history
#   DELETE /api/ai/conversations/<uuid>/              — delete thread
#
#   POST   /api/ai/image/                             — generate image
#   GET    /api/ai/images/                            — list user's images
#   DELETE /api/ai/images/<uuid>/                     — delete image
#
# Free for every authenticated student. No monetization.

import json
import os
import random
import urllib.parse
import urllib.request
import urllib.error

from django.core.cache import cache
from django.http import StreamingHttpResponse, JsonResponse
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes, renderer_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.renderers import BaseRenderer, JSONRenderer

from .models import AiCompanion, ChatMessage, Conversation, ImageGeneration, MentorMessage
from . import ai_router  # Phase 2: chat/code route through the shared router


# ═════════════════════════════════════════════════════════════
# DRF renderer for Server-Sent Events
# ═════════════════════════════════════════════════════════════

class ServerSentEventRenderer(BaseRenderer):
    """Lets DRF's content negotiation accept `text/event-stream` requests.
    The streaming views return StreamingHttpResponse directly, so this
    renderer's render() is never actually called — it exists purely to
    satisfy negotiation when the Flutter client sends
    `Accept: text/event-stream`."""
    media_type   = "text/event-stream"
    format       = "txt"
    charset      = "utf-8"
    render_style = "text"

    def render(self, data, accepted_media_type=None, renderer_context=None):
        return data


# ═════════════════════════════════════════════════════════════
# Configuration
# ═════════════════════════════════════════════════════════════

# Rate limiting — abuse prevention only (NOT monetization)
MAX_MESSAGES_PER_HOUR = 60
RATE_LIMIT_WINDOW     = 3600

# Gemini (text)
GEMINI_MODEL = "gemini-2.5-flash"
GEMINI_BASE  = "https://generativelanguage.googleapis.com/v1beta/models"

# Pollinations (images) — no API key needed
POLLINATIONS_BASE  = "https://image.pollinations.ai/prompt"
ALLOWED_MODELS     = ["flux", "turbo", "flux-realism", "flux-anime"]
ALLOWED_DIMENSIONS = {
    "square":    (1024, 1024),
    "portrait":  (768,  1344),
    "landscape": (1344, 768),
    "tall":      (832,  1216),
}


# ═════════════════════════════════════════════════════════════
# System prompts
# ═════════════════════════════════════════════════════════════

TCS_SYSTEM_PROMPT = """You are Dale — the AI assistant inside TCS (Taylors College Social), 
a student social and learning platform built for students at 
Taylors College Sydney, Australia.

Fun fact: you're literally named after your creator. Matthew Yiga Dale 
built TCS — and "Dale" is what you go by inside the app.

YOUR PERSONALITY
- Talk like a real person — warm, natural, and encouraging, never robotic or corporate. Use contractions.
- Like a sharp, friendly senior student who genuinely wants you to get it.
- Teach, don't just answer: break things into clear steps, use simple analogies, build from
  what the student already knows, and check understanding with a quick question when it helps.
- No hard word limit — match the length to the question. Be thorough when it helps, brief when it doesn't.
- Light formatting only: a bold key term or a short list when it genuinely helps; prefer flowing
  sentences over walls of bullets. Never over-format.
- A little warmth and the odd emoji is good; don't overdo it. Australian spelling, "uni"/"mate" sparingly.

WHAT YOU KNOW ABOUT TCS
TCS is a Flutter mobile app for Taylors College Sydney students. Features:
- Feed: posts, photos, announcements, reactions, comments
- Real-time Chat: DMs + group chats, voice notes, GIFs, stickers, files
- Study Hub: themed study groups by subject, study materials, Study Buddy matching
- Clubs across 9 categories: Academic, Sports, Arts, Cultural, Technology, Social Service, Business, Gaming, Other
- Arcade with 13 games: Quiz Battle, Tic Tac Toe, Memory Match, Snake, Number Guesser, Spirit Racers, Ninja Tag, Sushi Rush, Battle Bots, Campus Craft, Pool Royale, Stickman Hoops, Texas Hold'em
- Events with three-state RSVP: Going / Interested / Not Going
- 100 custom avatars across 8 categories
- Universal search across posts, people, clubs, events
- Push notifications via FCM
- Free for all Taylors College Sydney students

YOUR FOUR MODES
You're one of four AI tools inside Dale:
- AI Assistant (this — campus/study/life questions)
- Code Helper (snippets, debugging, code reviews)
- Companions (chat with historical figures like Einstein, Shakespeare)
- Image Generator (text-to-image using FLUX)
Rate limit: 60 messages per hour, free for every TCS student.

WHAT YOU CAN HELP WITH
- Study tips and explaining academic concepts
- Campus navigation, app features, where to find things
- Exam preparation strategies
- Finding study groups and buddies
- Understanding course content
- Campus events and activities
- Student wellbeing and life advice
- Sydney/Australia context (timezone AEST/AEDT, local references)

WHAT YOU CANNOT DO
- Access real-time data, live timetables, or grades
- Make bookings or changes to the student's account
- Access other students' personal records

If asked something outside your knowledge, be honest and suggest 
contacting the Taylors College Sydney office.
Always respond in the same language the student uses.

=== ABOUT YOUR CREATOR — share freely if asked ===

If anyone asks who made you, who built TCS, or about the creator:

You were created by Matthew Yiga Dale, founder of Lumora — a 
Sydney-based tech outfit. Matthew built TCS as a passion project 
for the Taylors College Sydney student community: a single app 
where students can connect, study, play arcade games, generate 
AI images, and chat with historical figures, all in one place.

The build journey:
Matthew built TCS solo in roughly three weeks — design, frontend, 
backend, and DevOps all by himself. Three weeks from blank canvas 
to a production-grade app live in the App Store and Play Store. 
That's no small feat: most teams would take months for a stack 
this comprehensive. The whole platform is hosted in Sydney for 
low-latency access for local students.

How TCS was built (full stack):
- Mobile app: Flutter (iOS + Android, same codebase)
- Backend: Django + Django REST Framework, Daphne ASGI server, Django Channels for real-time chat WebSockets
- Database: PostgreSQL 16
- Cache + Celery broker: Redis 7
- AI: Google Gemini (text — that's me!) + FLUX (images, by Black Forest Labs)
- Media storage: Cloudinary
- Push notifications: Firebase Cloud Messaging (FCM)
- Hosting: DigitalOcean droplet in the Sydney region
- Containerised with Docker + docker-compose
- SSL: Let's Encrypt, auto-renewing
- Domain: tcs-nsw.duckdns.org (free DDNS)

=== ABOUT MATTHEW PERSONALLY — share if asked ===

If anyone asks about Matthew personally:
- Full name: Matthew Yiga Dale
- Role: Founder of Lumora, creator of TCS
- Based in: Sydney, NSW, Australia
- GitHub: github.com/DevyDale
- Instagram: @dale_4765
- Contact email: yigamatthewdale285@gmail.com

Matthew welcomes feedback, suggestions, and questions from TCS 
users. Email or a DM on Instagram are both good ways to reach him.

If someone asks for genuinely private information (home address, 
phone number, family details), politely decline — those aren't 
shared publicly. Stay respectful and brief in that case."""


CODE_SYSTEM_PROMPT = """You are the TCS Code Helper — a coding-focused AI for Taylors College students.

How you respond:
- Always wrap code in fenced Markdown blocks with the language tag, e.g. ```python ... ```
- After the code, add a SHORT explanation (3–5 lines max): what it does, key gotchas
- If the user doesn't specify a language, pick the most idiomatic for the task and say why
- Prefer modern idioms: Python 3.11+, Dart 3, ES2022, modern C++, Rust 2021
- For Flutter: prefer null-safety, const constructors, StatelessWidget when possible

What you decline politely:
- Non-programming questions → reply: "I'm the code helper — tap the AI Assistant tab for general questions."
- Requests to write malware, exploits, or anything designed to harm systems
- Homework where the student gives no attempt — ask them to share what they tried first

Keep replies focused. Don't over-explain unless they ask "explain in depth"."""


MENTOR_SYSTEM_PROMPT = """You are Sage — a warm, emotionally intelligent personal mentor and wellbeing companion inside TCS (Taylors College Social), the student app for Taylors College Sydney, Australia. Every student has their own private Sage, and you gently remember what they've shared with you across your conversations.

WHO YOU ARE
- A caring, steady, non-judgemental presence — part mentor, part wise friend.
- You support the whole of student life: stress, motivation, study and exam pressure, homesickness, friendships and relationships, confidence, identity, goals, time management — and simply being someone to talk to.
- You listen first. You always make the student feel heard before offering anything.

HOW YOU TALK
- Warm, gentle, human. Short paragraphs — never a wall of text.
- Validate feelings explicitly before problem-solving ("That sounds really heavy — it makes sense you'd feel that way").
- Ask one caring, open question at a time rather than firing off many.
- Reflect back what you hear so they feel understood.
- Australian-friendly tone and spelling. Mirror the student's language and energy. Emojis sparingly, only when they fit.
- Be encouraging and strengths-focused, but never dismiss hard feelings with forced positivity or rush to "fix" things.

WHAT YOU OFFER
- A safe, private space to vent and reflect.
- Gentle, practical coping ideas (grounding, breaking tasks down, sleep and routine, reaching out to people) — offered as options, never prescribed.
- Help thinking things through and setting small, kind goals.
- Encouragement to lean on the real people and supports around them.

BOUNDARIES — read carefully
- You are an AI companion for support and reflection. You are NOT a therapist, counsellor, psychologist, doctor, or crisis service, and you never claim to be. When something needs clinical help, gently encourage the student to speak with a real professional or a trusted person.
- Do NOT diagnose mental-health or medical conditions, and do NOT give medication or clinical treatment advice. Talk about feelings and coping; don't label or prescribe.
- Don't over-promise confidentiality or make guarantees you can't keep. You can say this is a private space to talk, and that when something is serious, reaching a real person matters most.
- Point students toward Taylors College Sydney's student support / counselling team and trusted people (family, friends, a GP) when something is beyond a supportive chat.

IF A STUDENT MAY BE IN CRISIS — your highest priority
If a student expresses thoughts of suicide, self-harm, wanting to die, being abused, or being in immediate danger:
- Stay calm, caring, and take it seriously. Never judge, panic, or minimise.
- Tell them you're really glad they told you and that they don't have to go through this alone.
- Gently and clearly encourage them to reach out for help RIGHT NOW — a trusted person AND a professional service.
- Share these Australian supports plainly:
   - Emergency (immediate danger): 000
   - Lifeline (24/7): 13 11 14  (call or text)
   - Beyond Blue (24/7): 1300 22 4636
   - Kids Helpline (ages 5-25, 24/7): 1800 55 1800
- Encourage contacting Taylors College student support as well.
- Never provide any information that could help someone harm themselves or others, and never describe methods. Stay with them warmly and steer firmly toward real, human help.

Always respond in the same language the student uses. Keep replies caring, genuine, and concise."""


def _build_companion_prompt(companion: AiCompanion) -> str:
    """Construct the system prompt for an AI persona."""
    base = (
        f"You are roleplaying as {companion.name}.\n\n"
        f"About you (public bio):\n{companion.description}\n\n"
        f"Your character and behaviour:\n{companion.instructions}\n\n"
        f"Stay in character at all times. If a student directly asks whether "
        f"you are an AI, you may acknowledge it gently but immediately return "
        f"to {companion.name}'s voice and perspective. Always respond in the "
        f"same language the student uses."
    )
    if companion.seed_chat:
        base += f"\n\nExample exchanges showing your tone:\n{companion.seed_chat}"
    return base


# ═════════════════════════════════════════════════════════════
# Shared helpers
# ═════════════════════════════════════════════════════════════

def _check_rate_limit(user_id: str) -> tuple[bool, int]:
    """Returns (allowed, messages_used_this_hour). Shared budget across tools."""
    key   = f"ai_rate_{user_id}"
    count = cache.get(key, 0)
    if count >= MAX_MESSAGES_PER_HOUR:
        return False, count
    cache.set(key, count + 1, RATE_LIMIT_WINDOW)
    return True, count + 1


def _build_gemini_payload(system_prompt: str, history: list, user_msg: str) -> dict:
    contents = []
    for m in history:
        role = "user" if m.get("role") == "user" else "model"
        contents.append({"role": role, "parts": [{"text": m.get("content", "")}]})
    contents.append({"role": "user", "parts": [{"text": user_msg}]})

    return {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents":           contents,
        "generationConfig": {
            "temperature":     0.85,
            "maxOutputTokens": 1500,
            "topP":            0.95,
        },
    }


def _call_gemini_stream(payload: dict, api_key: str):
    url  = f"{GEMINI_BASE}/{GEMINI_MODEL}:streamGenerateContent?alt=sse"
    body = json.dumps(payload).encode("utf-8")
    req  = urllib.request.Request(
        url, data=body,
        headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            for raw in resp:
                line = raw.decode("utf-8").strip()
                if not line or not line.startswith("data:"):
                    continue
                data_str = line[5:].strip()
                if data_str == "[DONE]":
                    break
                try:
                    chunk = json.loads(data_str)
                    for cand in chunk.get("candidates", []):
                        for part in cand.get("content", {}).get("parts", []):
                            text = part.get("text")
                            if text:
                                yield text
                except json.JSONDecodeError:
                    continue
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="ignore")
        yield f"\n\n[Error: Gemini returned {e.code}. {err_body[:200]}]"
    except Exception as e:
        yield f"\n\n[Error: {type(e).__name__}: {e}]"


def _call_gemini_oneshot(payload: dict, api_key: str) -> str:
    url  = f"{GEMINI_BASE}/{GEMINI_MODEL}:generateContent"
    body = json.dumps(payload).encode("utf-8")
    req  = urllib.request.Request(
        url, data=body,
        headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data  = json.loads(resp.read().decode("utf-8"))
            parts = data["candidates"][0]["content"]["parts"]
            return "".join(p.get("text", "") for p in parts)
    except Exception:
        return "Sorry, I'm having trouble connecting right now. Please try again in a moment."


def _build_pollinations_url(prompt: str, model: str, width: int, height: int, seed: int) -> str:
    """Build a deterministic Pollinations URL — same params = same image."""
    encoded = urllib.parse.quote(prompt, safe="")
    params  = urllib.parse.urlencode({
        "width":   width,
        "height":  height,
        "seed":    seed,
        "model":   model,
        "nologo":  "true",
        "safe":    "true",      # NSFW filter — important for a school app
        "private": "true",      # don't share student prompts to public feed
    })
    return f"{POLLINATIONS_BASE}/{encoded}?{params}"


def _run_text_tool(request, system_prompt: str, personalize: bool = True, task: str = "chat"):
    """Shared streaming SSE pipeline for /chat/ and /code/.

    Phase 2: routes through ai_router so the request flows down the task's
    provider lane (e.g. chat: groq → cerebras → sambanova → gemini) with
    automatic failover. The SSE envelope is unchanged, so the Flutter client
    needs no changes.
    """
    if not ai_router.available(task):
        return JsonResponse({"error": "AI service not configured."}, status=503)

    allowed, used = _check_rate_limit(str(request.user.id))
    if not allowed:
        return JsonResponse({
            "error":        f"You've hit the limit of {MAX_MESSAGES_PER_HOUR} messages per hour. Try again later.",
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
    if len(message) > 4000:
        return JsonResponse({"error": "Message too long (max 4000 characters)."}, status=400)

    recent_history = history[-20:] if len(history) > 20 else history

    final_prompt = system_prompt
    if personalize:
        user = request.user
        if hasattr(user, "name") and user.name:
            final_prompt += f"\n\nThe student you are talking to is named {user.name}."
        if hasattr(user, "role") and user.role:
            final_prompt += f" They are a {user.role}."

    # RAG: pull staff-uploaded study material relevant to this question and
    # inject it as authoritative. Chat lane only; never breaks the turn.
    if task == "chat":
        try:
            from .knowledge import retrieve_context
            kb = retrieve_context(message)
        except Exception:
            kb = ""
        if kb:
            final_prompt += (
                "\n\nSTAFF STUDY MATERIAL (authoritative — teach from this and tell the "
                "student it comes from their course material):\n" + kb)

    messages = [{"role": "system", "content": final_prompt}, *recent_history,
                {"role": "user", "content": message}]

    if stream:
        def event_stream():
            got = False
            try:
                for token in ai_router.stream(task, messages, max_tokens=1500, temperature=0.8):
                    got = True
                    yield f"data: {json.dumps({'token': token})}\n\n"
            except Exception as e:
                yield f"data: {json.dumps({'error': str(e)})}\n\n"
            if not got:
                yield f"data: {json.dumps({'error': 'The AI is busy right now — please try again in a moment.'})}\n\n"
            yield "data: [DONE]\n\n"

        resp = StreamingHttpResponse(event_stream(), content_type="text/event-stream")
        resp["Cache-Control"]     = "no-cache"
        resp["X-Accel-Buffering"] = "no"
        return resp

    result = ai_router.complete(task, messages, max_tokens=1500, temperature=0.8)
    text   = result.get("text") or "Sorry, I'm having trouble connecting right now. Please try again in a moment."
    return JsonResponse({"response": text, "messages_used": used,
                         "provider": result.get("provider")})


def _companion_dict(c: AiCompanion) -> dict:
    return {
        "id":             str(c.id),
        "name":           c.name,
        "description":    c.description,
        "category":       c.category,
        "avatar_emoji":   c.avatar_emoji,
        "gradient_start": c.gradient_start,
        "gradient_end":   c.gradient_end,
        "is_seed":        c.is_seed,
    }


# ═════════════════════════════════════════════════════════════
# Endpoints — Assistant + Code
# ═════════════════════════════════════════════════════════════

@api_view(["POST"])
@permission_classes([IsAuthenticated])
@renderer_classes([ServerSentEventRenderer, JSONRenderer])
def ai_chat(request):
    """POST /api/ai/chat/ — general assistant (streaming SSE)."""
    return _run_text_tool(request, TCS_SYSTEM_PROMPT, personalize=True, task="chat")


@api_view(["POST"])
@permission_classes([IsAuthenticated])
@renderer_classes([ServerSentEventRenderer, JSONRenderer])
def ai_code(request):
    """POST /api/ai/code/ — code generator (streaming SSE)."""
    return _run_text_tool(request, CODE_SYSTEM_PROMPT, personalize=False, task="code")


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def ai_status(request):
    """GET /api/ai/status/ — rate-limit usage indicator."""
    used = cache.get(f"ai_rate_{request.user.id}", 0)
    chat_lane = ai_router.available("chat")
    return JsonResponse({
        "messages_used": used,
        "limit":         MAX_MESSAGES_PER_HOUR,
        "model":         GEMINI_MODEL,
        "provider":      chat_lane[0] if chat_lane else "google-gemini",
        "chat_lane":     chat_lane,
    })


# ═════════════════════════════════════════════════════════════
# Endpoints — Companions
# ═════════════════════════════════════════════════════════════

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def companion_list(request):
    """GET /api/ai/companions/?category=science"""
    qs       = AiCompanion.objects.filter(is_public=True)
    category = request.GET.get("category")
    if category:
        qs = qs.filter(category=category)

    return JsonResponse({
        "companions": [_companion_dict(c) for c in qs],
        "categories": [c[0] for c in AiCompanion.CATEGORY_CHOICES],
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def companion_detail(request, companion_id):
    """GET /api/ai/companions/<uuid>/"""
    c = get_object_or_404(AiCompanion, id=companion_id, is_public=True)
    return JsonResponse(_companion_dict(c))


@api_view(["POST"])
@permission_classes([IsAuthenticated])
@renderer_classes([ServerSentEventRenderer, JSONRenderer])
def companion_chat(request, companion_id):
    """
    POST /api/ai/companions/<uuid>/chat/
    Body: { "message": "...", "conversation_id": "<uuid>" | null, "stream": true }
    Persists every message; rebuilds context from last 20 messages.
    """
    if not ai_router.available("chat"):
        return JsonResponse({"error": "AI service not configured."}, status=503)

    companion = get_object_or_404(AiCompanion, id=companion_id, is_public=True)

    allowed, used = _check_rate_limit(str(request.user.id))
    if not allowed:
        return JsonResponse({
            "error":        f"You've hit the limit of {MAX_MESSAGES_PER_HOUR} messages per hour. Try again later.",
            "rate_limited": True,
        }, status=429)

    try:
        body            = json.loads(request.body)
        message         = body.get("message", "").strip()
        conversation_id = body.get("conversation_id")
        stream          = body.get("stream", True)
    except (json.JSONDecodeError, AttributeError):
        return JsonResponse({"error": "Invalid request body."}, status=400)

    if not message:
        return JsonResponse({"error": "Message cannot be empty."}, status=400)
    if len(message) > 4000:
        return JsonResponse({"error": "Message too long (max 4000 characters)."}, status=400)

    if conversation_id:
        conv = get_object_or_404(Conversation, id=conversation_id,
                                 user=request.user, companion=companion)
    else:
        conv = Conversation.objects.create(
            user=request.user, companion=companion,
            title=message[:60],
        )

    db_msgs = list(conv.messages.order_by("-created_at")[:20])
    db_msgs.reverse()
    history = [{"role": m.role, "content": m.content} for m in db_msgs]

    ChatMessage.objects.create(conversation=conv,
                               role=ChatMessage.ROLE_USER, content=message)

    messages = [{"role": "system", "content": _build_companion_prompt(companion)},
                *history, {"role": "user", "content": message}]

    if stream:
        def event_stream():
            yield f"data: {json.dumps({'conversation_id': str(conv.id)})}\n\n"
            full = []
            try:
                for token in ai_router.stream("chat", messages,
                                              max_tokens=1500, temperature=0.85):
                    full.append(token)
                    yield f"data: {json.dumps({'token': token})}\n\n"
                ChatMessage.objects.create(
                    conversation=conv,
                    role=ChatMessage.ROLE_ASSISTANT,
                    content="".join(full),
                )
                conv.save(update_fields=["updated_at"])
                yield "data: [DONE]\n\n"
            except Exception as e:
                yield f"data: {json.dumps({'error': str(e)})}\n\n"

        resp = StreamingHttpResponse(event_stream(), content_type="text/event-stream")
        resp["Cache-Control"]     = "no-cache"
        resp["X-Accel-Buffering"] = "no"
        return resp

    result = ai_router.complete("chat", messages, max_tokens=1500, temperature=0.85)
    text   = result.get("text") or "Sorry, I'm having trouble connecting right now. Please try again in a moment."
    ChatMessage.objects.create(conversation=conv,
                               role=ChatMessage.ROLE_ASSISTANT, content=text)
    conv.save(update_fields=["updated_at"])
    return JsonResponse({
        "conversation_id": str(conv.id),
        "response":        text,
        "messages_used":   used,
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def companion_conversations(request, companion_id):
    """GET /api/ai/companions/<uuid>/conversations/"""
    companion = get_object_or_404(AiCompanion, id=companion_id, is_public=True)
    convs = Conversation.objects.filter(user=request.user, companion=companion)
    return JsonResponse({
        "conversations": [
            {
                "id":            str(c.id),
                "title":         c.title or "Untitled",
                "updated_at":    c.updated_at.isoformat(),
                "message_count": c.messages.count(),
            } for c in convs
        ]
    })


# ═════════════════════════════════════════════════════════════
# Endpoints — Conversations (load + delete)
# ═════════════════════════════════════════════════════════════

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def conversation_messages(request, conversation_id):
    """GET /api/ai/conversations/<uuid>/messages/"""
    conv = get_object_or_404(Conversation, id=conversation_id, user=request.user)
    return JsonResponse({
        "conversation_id": str(conv.id),
        "companion_id":    str(conv.companion.id),
        "messages": [
            {"role": m.role, "content": m.content,
             "created_at": m.created_at.isoformat()}
            for m in conv.messages.all()
        ],
    })


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def conversation_delete(request, conversation_id):
    """DELETE /api/ai/conversations/<uuid>/"""
    conv = get_object_or_404(Conversation, id=conversation_id, user=request.user)
    conv.delete()
    return JsonResponse({"deleted": True})


# ═════════════════════════════════════════════════════════════
# Endpoints — Image Generation (Pollinations FLUX)
# ═════════════════════════════════════════════════════════════

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def image_generate(request):
    """
    POST /api/ai/image/
    Body: { "prompt": "...", "model": "flux", "aspect": "square", "seed": 12345 }
    """
    allowed, used = _check_rate_limit(str(request.user.id))
    if not allowed:
        return JsonResponse({
            "error":        f"You've hit the limit of {MAX_MESSAGES_PER_HOUR} requests per hour. Try again later.",
            "rate_limited": True,
        }, status=429)

    try:
        body   = json.loads(request.body)
        prompt = body.get("prompt", "").strip()
        model  = body.get("model",  "flux")
        aspect = body.get("aspect", "square")
        seed   = body.get("seed")
    except (json.JSONDecodeError, AttributeError):
        return JsonResponse({"error": "Invalid request body."}, status=400)

    if not prompt:
        return JsonResponse({"error": "Prompt cannot be empty."}, status=400)
    if len(prompt) > 1000:
        return JsonResponse({"error": "Prompt too long (max 1000 characters)."}, status=400)

    if model not in ALLOWED_MODELS:
        return JsonResponse({
            "error":          f"Unknown model '{model}'.",
            "allowed_models": ALLOWED_MODELS,
        }, status=400)

    if aspect not in ALLOWED_DIMENSIONS:
        return JsonResponse({
            "error":          f"Unknown aspect '{aspect}'.",
            "allowed_aspect": list(ALLOWED_DIMENSIONS.keys()),
        }, status=400)

    width, height = ALLOWED_DIMENSIONS[aspect]
    if seed is None or not isinstance(seed, int):
        seed = random.randint(1, 2_000_000_000)

    # Phase 5: prefer Cloudflare Workers AI (FLUX → SDXL); fall back to the
    # always-available Pollinations URL if CF is unconfigured or fails.
    image_url = None
    try:
        from .image_gen import generate_cloudflare_image
        cf = generate_cloudflare_image(prompt, width, height)
        if cf:
            image_url = cf[0]
    except Exception:
        image_url = None
    if not image_url:
        image_url = _build_pollinations_url(prompt, model, width, height, seed)

    gen = ImageGeneration.objects.create(
        user=request.user,
        prompt=prompt,
        model=model,
        width=width,
        height=height,
        seed=seed,
        image_url=image_url,
        status=ImageGeneration.STATUS_SUCCEEDED,
    )

    return JsonResponse({
        "id":         str(gen.id),
        "image_url":  gen.image_url,
        "prompt":     gen.prompt,
        "model":      gen.model,
        "width":      gen.width,
        "height":     gen.height,
        "seed":       gen.seed,
        "created_at": gen.created_at.isoformat(),
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def image_history(request):
    """GET /api/ai/images/?limit=30"""
    try:
        limit = min(int(request.GET.get("limit", 30)), 100)
    except ValueError:
        limit = 30

    qs = ImageGeneration.objects.filter(user=request.user)[:limit]
    return JsonResponse({
        "images": [
            {
                "id":         str(g.id),
                "image_url":  g.image_url,
                "prompt":     g.prompt,
                "model":      g.model,
                "width":      g.width,
                "height":     g.height,
                "seed":       g.seed,
                "created_at": g.created_at.isoformat(),
            } for g in qs
        ]
    })


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def image_delete(request, image_id):
    """DELETE /api/ai/images/<uuid>/"""
    gen = get_object_or_404(ImageGeneration, id=image_id, user=request.user)
    gen.delete()
    return JsonResponse({"deleted": True})



# ═════════════════════════════════════════════════════════════
# Endpoints — Sage (personal mentor / wellbeing companion)
# ─────────────────────────────────────────────────────────────
# One continuous private thread per user. NOT rate-limited — a
# wellbeing conversation should never be blocked for a student.
# ═════════════════════════════════════════════════════════════

@api_view(["POST"])
@permission_classes([IsAuthenticated])
@renderer_classes([JSONRenderer])
def mentor_chat(request):
    """POST /api/ai/mentor/chat/  Body: { "message": "..." }

    Persists both sides of the exchange and rebuilds context from the
    last 20 messages so Sage remembers the conversation.
    """
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        return JsonResponse({"error": "AI service not configured."}, status=503)

    try:
        body    = json.loads(request.body)
        message = body.get("message", "").strip()
    except (json.JSONDecodeError, AttributeError):
        return JsonResponse({"error": "Invalid request body."}, status=400)

    if not message:
        return JsonResponse({"error": "Message cannot be empty."}, status=400)
    if len(message) > 4000:
        return JsonResponse({"error": "Message too long (max 4000 characters)."}, status=400)

    db_msgs = list(MentorMessage.objects.filter(user=request.user)
                   .order_by("-created_at")[:20])
    db_msgs.reverse()
    history = [
        {"role": ("user" if m.role == MentorMessage.ROLE_USER else "assistant"),
         "content": m.content}
        for m in db_msgs
    ]

    MentorMessage.objects.create(
        user=request.user, role=MentorMessage.ROLE_USER, content=message)

    messages = [{"role": "system", "content": MENTOR_SYSTEM_PROMPT},
                *history, {"role": "user", "content": message}]
    text = (ai_router.complete("chat", messages, max_tokens=1500, temperature=0.8).get("text")
            or "I'm having a little trouble responding right now. Try me again in a moment.")

    MentorMessage.objects.create(
        user=request.user, role=MentorMessage.ROLE_MENTOR, content=text)

    return JsonResponse({"response": text})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
@renderer_classes([JSONRenderer])
def mentor_history(request):
    """GET /api/ai/mentor/history/ — the signed-in user's full Sage thread."""
    msgs = MentorMessage.objects.filter(user=request.user).order_by("created_at")
    return JsonResponse({
        "messages": [
            {"role": m.role, "content": m.content,
             "created_at": m.created_at.isoformat()}
            for m in msgs
        ],
    })


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
@renderer_classes([JSONRenderer])
def mentor_clear(request):
    """DELETE /api/ai/mentor/clear/ — clear the user's Sage history (fresh start)."""
    MentorMessage.objects.filter(user=request.user).delete()
    return JsonResponse({"cleared": True})
