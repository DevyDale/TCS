# apps/ai/image_gen.py
#
# Phase 5 — image generation via Cloudflare Workers AI (free): FLUX-1-schnell
# primary, Stable Diffusion XL fallback. Returns a hosted URL (bytes are
# uploaded to Cloudinary). Falls back to the existing Pollinations path when
# Cloudflare isn't configured or both models fail, so images never break.
#
# Cloudflare Workers AI needs BOTH env vars set to activate:
#   CLOUDFLARE_ACCOUNT_ID   (the 32-char account id — required for the URL)
#   CLOUDFLARE_API_TOKEN    (a token with the Workers AI permission)

import base64
import json
import logging
import os
import urllib.error
import urllib.request

logger = logging.getLogger(__name__)

# (model id, label) in failover order.
_CF_MODELS = [
    ("@cf/black-forest-labs/flux-1-schnell",          "flux-schnell"),
    ("@cf/stabilityai/stable-diffusion-xl-base-1.0",  "sdxl"),
]


def cloudflare_available():
    return bool(os.environ.get("CLOUDFLARE_ACCOUNT_ID", "").strip()
                and os.environ.get("CLOUDFLARE_API_TOKEN", "").strip())


def _cf_run(model, prompt, width, height):
    acct  = os.environ["CLOUDFLARE_ACCOUNT_ID"].strip()
    token = os.environ["CLOUDFLARE_API_TOKEN"].strip()
    url   = f"https://api.cloudflare.com/client/v4/accounts/{acct}/ai/run/{model}"

    body = {"prompt": prompt}
    if "flux" in model:
        body["steps"] = 6                       # schnell is a few-step model
    else:
        body["width"], body["height"] = width, height

    req = urllib.request.Request(
        url, data=json.dumps(body).encode("utf-8"),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST")
    with urllib.request.urlopen(req, timeout=60) as resp:
        ctype = resp.headers.get("Content-Type", "")
        data  = resp.read()
        if "application/json" in ctype:          # FLUX → {"result": {"image": "<base64>"}}
            j   = json.loads(data.decode("utf-8"))
            b64 = (j.get("result") or {}).get("image")
            if not b64:
                raise RuntimeError("Cloudflare returned no image")
            return base64.b64decode(b64)
        return data                              # SDXL → raw PNG bytes


def _upload_to_cloudinary(img_bytes):
    import cloudinary.uploader
    data_uri = "data:image/png;base64," + base64.b64encode(img_bytes).decode("ascii")
    res = cloudinary.uploader.upload(
        data_uri, folder="tcs/ai_images", resource_type="image")
    return res.get("secure_url")


def generate_cloudflare_image(prompt, width, height):
    """Try CF FLUX then SDXL, upload to Cloudinary, return (url, label).

    Returns None if Cloudflare isn't configured or every model/upload failed —
    the caller then falls back to Pollinations.
    """
    if not cloudflare_available():
        return None
    for model, label in _CF_MODELS:
        try:
            img = _cf_run(model, prompt, width, height)
            url = _upload_to_cloudinary(img)
            if url:
                return url, label
        except urllib.error.HTTPError as e:
            logger.warning("CF image %s HTTP %s: %s", model, e.code,
                           e.read().decode("utf-8", "replace")[:160])
        except Exception as e:  # noqa: BLE001
            logger.warning("CF image %s failed: %s", model, e)
    return None
