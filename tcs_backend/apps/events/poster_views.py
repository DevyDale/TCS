"""Flux AI event poster generator (Replicate's Flux Schnell).

Endpoint: POST /api/events/generate-poster/
  body: {"prompt": str, "title": str (optional), "club_id": str (optional)}
  returns: {"poster_url": str, "prompt": str}

Requires REPLICATE_API_TOKEN env var. Free tier covers ~thousands of
generations. Get a token at https://replicate.com/account/api-tokens
"""
import os, json
import urllib.request, urllib.error

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response


def _replicate_poster(full_prompt, token):
    """Flux Schnell via Replicate. Returns a URL or raises."""
    body = json.dumps({
        "input": {
            "prompt": full_prompt,
            "aspect_ratio": "3:4",
            "output_format": "jpg",
            "num_inference_steps": 4,
        }
    }).encode('utf-8')
    req = urllib.request.Request(
        'https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions',
        data=body,
        headers={
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
            'Prefer': 'wait',
        },
    )
    with urllib.request.urlopen(req, timeout=90) as resp:
        data = json.loads(resp.read().decode('utf-8'))
    output = data.get('output')
    if isinstance(output, list) and output:
        return output[0]
    if isinstance(output, str):
        return output
    return None


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def generate_event_poster(request):
    prompt = (request.data.get('prompt') or '').strip()
    title = (request.data.get('title') or '').strip()
    if not prompt:
        return Response({"error": "prompt is required"}, status=400)

    full_prompt = (f"{title}. {prompt}" if title else prompt) + \
        ", professional event poster, vibrant colors, bold typography, eye-catching design"

    # 1) Try Replicate/Flux if a token is configured AND it has credit. Any
    #    failure (no token, 402 insufficient credit, timeout) falls through to
    #    the free generator so a poster always comes back.
    token = os.environ.get('REPLICATE_API_TOKEN', '').strip()
    if token:
        try:
            url = _replicate_poster(full_prompt, token)
            if url:
                return Response({'poster_url': url, 'prompt': full_prompt,
                                 'provider': 'flux'})
        except Exception:
            pass  # fall back to the free generator below

    # 2) Free fallback — Pollinations builds the image on access (no key, no
    #    credit). The returned URL is itself the rendered poster.
    import random
    import urllib.parse
    seed = random.randint(1, 1_000_000)
    encoded = urllib.parse.quote(full_prompt, safe='')
    poster_url = (
        f"https://image.pollinations.ai/prompt/{encoded}"
        f"?width=768&height=1024&nologo=true&seed={seed}&model=flux"
    )
    return Response({'poster_url': poster_url, 'prompt': full_prompt,
                     'provider': 'pollinations'})
