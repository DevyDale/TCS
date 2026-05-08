# TCS/asgi.py
import os

# 1. Load .env FIRST — before any Django or app imports
from dotenv import load_dotenv
load_dotenv()

# 2. Tell Django which settings module to use
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "TCS.settings.development")

# 3. Initialise Django
import django
django.setup()

# 4. NOW it's safe to import Django + your apps
from django.core.asgi import get_asgi_application
from django.urls import re_path
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator

from apps.chat.middleware         import JWTAuthMiddlewareStack
from apps.chat.consumers          import ChatConsumer
from apps.notifications.consumers import NotificationConsumer
from apps.arcade.consumers        import MatchConsumer

websocket_urlpatterns = [
    re_path(r"^ws/chat/(?P<room_id>[0-9a-f-]+)/$",              ChatConsumer.as_asgi()),
    re_path(r"^ws/notifications/$",                             NotificationConsumer.as_asgi()),
    re_path(r"^ws/arcade/match/(?P<session_id>[0-9a-f-]+)/$",   MatchConsumer.as_asgi()),
]

application = ProtocolTypeRouter({
    "http": get_asgi_application(),
    "websocket": AllowedHostsOriginValidator(
        JWTAuthMiddlewareStack(URLRouter(websocket_urlpatterns))
    ),
})