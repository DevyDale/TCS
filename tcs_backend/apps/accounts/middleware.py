"""Presence middleware: updates User.last_seen + is_online on authenticated requests.

Runs AFTER the view returns, so DRF's JWT auth has already populated request.user.
Throttled to one DB write per user per PRESENCE_THROTTLE_SECONDS (default 60s) to
avoid hammering the DB on every API call.
"""
from django.utils import timezone

PRESENCE_THROTTLE_SECONDS = 60


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
