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


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def generate_event_poster(request):
    prompt = (request.data.get('prompt') or '').strip()
    title = (request.data.get('title') or '').strip()
    if not prompt:
        return Response({"error": "prompt is required"}, status=400)

    token = os.environ.get('REPLICATE_API_TOKEN', '').strip()
    if not token:
        return Response({
            "error": (
                "REPLICATE_API_TOKEN not set on the server. "
                "Get a token at https://replicate.com/account/api-tokens "
                "and add REPLICATE_API_TOKEN=... to your Django env."
            )
        }, status=503)

    full_prompt = (f"{title}. {prompt}" if title else prompt) + \
                  ", professional event poster, vibrant colors, bold typography, eye-catching design"

    try:
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
        poster_url = None
        if isinstance(output, list) and output:
            poster_url = output[0]
        elif isinstance(output, str):
            poster_url = output

        if not poster_url:
            return Response({"error": "Replicate returned no output URL", "data": data}, status=502)

        return Response({'poster_url': poster_url, 'prompt': full_prompt})
    except urllib.error.HTTPError as e:
        err_body = ''
        try: err_body = e.read().decode('utf-8')
        except Exception: pass
        return Response({"error": f"Replicate HTTP {e.code}: {err_body}"}, status=502)
    except Exception as e:
        return Response({"error": f"Poster generation failed: {type(e).__name__}: {e}"}, status=500)
