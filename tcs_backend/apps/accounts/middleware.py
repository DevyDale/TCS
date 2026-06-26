"""Presence middleware: updates User.last_seen + is_online on authenticated requests.

Runs AFTER the view returns, so DRF's JWT auth has already populated request.user.
Throttled to one DB write per user per PRESENCE_THROTTLE_SECONDS (default 60s) to
avoid hammering the DB on every API call.
"""
import logging

from django.http import JsonResponse
from django.utils import timezone

logger = logging.getLogger(__name__)

PRESENCE_THROTTLE_SECONDS = 60

# ── Showcase lockdown (safeguarding gate) ──────────────────────────────
# Visitor/parent are self-registered, email-only, lowest-trust accounts on a
# platform that contains minors. They are DENIED BY DEFAULT on every API path
# except the explicit showcase + auth allow-list below — enforced here, not in
# the client, and regardless of any per-view permissions.
_LOW_TRUST_ROLES = {"visitor", "parent"}
_SHOWCASE_ALLOW_PREFIXES = (
    "/api/showcase/",
)
_SHOWCASE_ALLOW_EXACT = {
    "/api/accounts/login-password/",
    "/api/accounts/register/",
    "/api/accounts/logout/",
    "/api/accounts/token/refresh/",
    "/api/users/me/",
}


class ShowcaseLockdownMiddleware:
    """Server-side deny-by-default for visitor/parent accounts."""

    def __init__(self, get_response):
        self.get_response = get_response

    def _role(self, request):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return None
        token = auth.split(" ", 1)[1].strip()
        try:
            from rest_framework_simplejwt.tokens import AccessToken
            tok = AccessToken(token)
        except Exception:
            return None  # invalid/expired — DRF will reject it in the view
        role = tok.get("role")
        if role:
            return role
        # Token predates the role claim — resolve from DB (short-TTL cache).
        uid = tok.get("user_id")
        if not uid:
            return None
        from django.core.cache import cache
        ckey = f"jwt_role_{uid}"
        role = cache.get(ckey)
        if role is None:
            try:
                from django.contrib.auth import get_user_model
                u = get_user_model().objects.filter(id=uid).only("role").first()
                role = (getattr(u, "role", "") or "") if u else ""
                cache.set(ckey, role, 300)
            except Exception:
                return None
        return role

    def __call__(self, request):
        path = request.path
        if path.startswith("/api/"):
            role = self._role(request)
            if role in _LOW_TRUST_ROLES:
                allowed = path in _SHOWCASE_ALLOW_EXACT or \
                    any(path.startswith(p) for p in _SHOWCASE_ALLOW_PREFIXES)
                if not allowed:
                    return JsonResponse(
                        {"detail": "This area isn't available for visitor "
                                   "accounts."},
                        status=403)
        return self.get_response(request)


class UpdateLastSeenMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Run view first — JWT auth fires inside DRF, populating request.user.
        response = self.get_response(request)

        user = getattr(request, "user", None)
        if user is None or not getattr(user, "is_authenticated", False):
            return response

        try:
            now = timezone.now()
            last = getattr(user, "last_seen", None)
            if last is None or (now - last).total_seconds() > PRESENCE_THROTTLE_SECONDS:
                user.last_seen = now
                if not getattr(user, "is_online", False):
                    user.is_online = True
                    user.save(update_fields=["last_seen", "is_online"])
                else:
                    user.save(update_fields=["last_seen"])
        except Exception:
            # Never let presence tracking break a request.
            pass

        return response
