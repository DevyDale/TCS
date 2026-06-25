# apps/ai/translate_views.py
#
# Batch UI translation, backed by the AI router (free via Groq) with Redis
# caching. The app sends the English UI strings it needs + a target language;
# we return a map of translations. Cached per (target, string) so each string
# is only ever translated once across all users.

import hashlib
import json

from django.core.cache import cache
from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated

from . import ai_router

_TTL = 60 * 60 * 24 * 60  # cache a translation for 60 days
_MAX = 120                # cap strings per request

_LANG_NAMES = {
    "ms": "Malay", "zh": "Chinese (Simplified)", "ja": "Japanese",
    "ko": "Korean", "ar": "Arabic", "fr": "French", "es": "Spanish",
    "de": "German", "hi": "Hindi", "pt": "Portuguese", "id": "Indonesian",
    "sw": "Swahili", "th": "Thai", "vi": "Vietnamese",
}


def _ckey(target, text):
    return "tr::%s::%s" % (target, hashlib.md5(text.encode("utf-8")).hexdigest())


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def ai_translate(request):
    """POST /api/ai/translate/  body: {texts: [...], target: 'fr'}
    -> {translations: {original: translated, ...}}"""
    try:
        body   = json.loads(request.body)
        texts  = body.get("texts") or []
        target = (body.get("target") or "").strip().lower()
    except (json.JSONDecodeError, AttributeError):
        return JsonResponse({"error": "Invalid request body."}, status=400)

    texts = [t for t in texts if isinstance(t, str) and t.strip()]
    # de-dupe, preserve order, cap
    seen, uniq = set(), []
    for t in texts:
        if t not in seen:
            seen.add(t); uniq.append(t)
    uniq = uniq[:_MAX]

    # English (or no target) → identity
    if not target or target == "en":
        return JsonResponse({"translations": {t: t for t in uniq}})

    out, missing = {}, []
    for t in uniq:
        hit = cache.get(_ckey(target, t))
        if hit is not None:
            out[t] = hit
        else:
            missing.append(t)

    if missing:
        lang = _LANG_NAMES.get(target, target)
        indexed = {str(i): t for i, t in enumerate(missing)}
        system = (
            f"You are a professional mobile-app UI translator. Translate each value "
            f"into {lang}. Keep it natural and concise for a phone UI. Preserve "
            f"placeholders (like {{name}}, %s, $count), emojis, leading/trailing "
            f"punctuation and symbols (e.g. the '›' arrow). Do NOT translate brand "
            f"names (TCS, Dale, Sage, Lumora). Return ONLY a JSON object with the "
            f"SAME keys as given and the translated strings as values."
        )
        result = ai_router.complete(
            "chat",
            [{"role": "system", "content": system},
             {"role": "user", "content": json.dumps(indexed, ensure_ascii=False)}],
            max_tokens=2000, temperature=0.2,
            response_format={"type": "json_object"},
        )
        try:
            data = json.loads((result.get("text") or "{}"))
            if not isinstance(data, dict):
                data = {}
        except Exception:
            data = {}
        for i, t in indexed.items():
            tr = data.get(i)
            tr = tr if isinstance(tr, str) and tr.strip() else t
            out[t] = tr
            cache.set(_ckey(target, t), tr, _TTL)

    return JsonResponse({"translations": out})
