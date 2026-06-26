from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView

api_v1 = [
    path("accounts/",      include("apps.accounts.urls")),
    path("activity/",    include("apps.activity.urls")),
    path("users/",         include("apps.accounts.user_urls")),
    path("dataentry/",     include("apps.dataentry.urls")),
    path("posts/",         include("apps.posts.urls")),
    path("highlights/",    include("apps.highlights.urls")),
    path("hashtags/",      include("apps.posts.hashtag_urls")),
    path("feelings/",      include("apps.posts.feeling_urls")),
    path("chat/",          include("apps.chat.urls")),
    path("groups/",        include("apps.groups.urls")),
    path("events/",        include("apps.events.urls")),
    path("arcade/",        include("apps.arcade.urls")),
    path("clubs/",         include("apps.clubs.urls")),
    path("notifications/", include("apps.notifications.urls")),
    path("announcements/", include("apps.notifications.announcement_urls")),
    path("moderation/",    include("apps.moderation.urls")),
    path("quiz/",          include("apps.quiz.urls")),
    path("feedback/",      include("apps.feedback.urls")),
    path("safety/",        include("apps.safety.urls")),
    # path("media/",         include("apps.media.urls")),  # TODO: apps.media not in INSTALLED_APPS
    path("ai/",            include("apps.ai.urls")),       # ← ADD THIS LINE
    path("schema/",        SpectacularAPIView.as_view(),                        name="schema"),
    path("docs/",          SpectacularSwaggerView.as_view(url_name="schema"),   name="swagger-ui"),
    path("redoc/",         SpectacularRedocView.as_view(url_name="schema"),     name="redoc"),
]

# ── Admin MFA enforcement (django-otp) ───────────────────────
# When OTP_ADMIN_ENFORCED is on, swap the default admin site for the OTP-gated
# one so the /admin/ login requires a TOTP code alongside the password. Gated
# by the flag so the package can ship un-enforced first (enroll-first). The
# import lives inside the conditional so the project still loads if django_otp
# isn't installed yet. Instant rollback: set OTP_ADMIN_ENFORCED=False, restart.
if getattr(settings, "OTP_ADMIN_ENFORCED", False):
    from django_otp.admin import OTPAdminSite
    admin.site.__class__ = OTPAdminSite

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/",   include(api_v1)),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
