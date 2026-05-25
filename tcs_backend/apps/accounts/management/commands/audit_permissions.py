"""
audit_permissions — list every API route and whether token-less (anonymous)
access is allowed under the CURRENT settings.

Run this after flipping DEFAULT_PERMISSION_CLASSES to confirm the only routes
that still allow anonymous access are the intended public ones (login,
login-password, register, token refresh, student/staff verify, dataentry
registration, and the API docs). Anything unexpected in the ANONYMOUS list is
something to review; anything you expect to be public but shows up under
AUTH-REQUIRED is what you'd add an explicit `permission_classes = [AllowAny]`
to before deploying.

Read-only. Safe to run anywhere (local, or `docker compose exec web ...`).

    python manage.py audit_permissions
"""
from django.core.management.base import BaseCommand
from django.urls import get_resolver
from django.urls.resolvers import URLPattern, URLResolver


def _walk(patterns, prefix=""):
    for p in patterns:
        if isinstance(p, URLResolver):
            yield from _walk(p.url_patterns, prefix + str(p.pattern))
        elif isinstance(p, URLPattern):
            yield prefix + str(p.pattern), p.callback


def _perm_names(callback):
    # DRF class-based views and @api_view functions both expose `.cls`.
    cls = getattr(callback, "cls", None) or getattr(callback, "view_class", None)
    if cls is None:
        return None  # non-DRF route (admin, static, etc.) — not relevant here
    perms = getattr(cls, "permission_classes", None)
    if perms is None:
        return []
    return [getattr(pc, "__name__", str(pc)) for pc in perms]


class Command(BaseCommand):
    help = "List each route and whether anonymous (token-less) access is allowed."

    def handle(self, *args, **options):
        anon, auth, skipped = [], [], 0
        for route, callback in _walk(get_resolver().url_patterns):
            names = _perm_names(callback)
            if names is None:
                skipped += 1
                continue
            allows_anon = (len(names) == 0) or ("AllowAny" in names)
            entry = ("/" + route, ", ".join(names) or "(no permission classes)")
            (anon if allows_anon else auth).append(entry)

        self.stdout.write(self.style.WARNING(
            "\n=== ANONYMOUS-ALLOWED routes (%d) — confirm ONLY intended public "
            "endpoints appear here ===\n" % len(anon)))
        for route, perms in sorted(anon):
            self.stdout.write("  [ANON]  %-45s -> %s" % (route, perms))

        self.stdout.write(self.style.SUCCESS(
            "\n=== AUTH-REQUIRED routes (%d) ===\n" % len(auth)))
        for route, perms in sorted(auth):
            self.stdout.write("  [AUTH]  %-45s -> %s" % (route, perms))

        self.stdout.write("")
        self.stdout.write(self.style.SUCCESS(
            "Summary: %d anonymous-allowed, %d auth-required, %d non-DRF routes skipped."
            % (len(anon), len(auth), skipped)))
