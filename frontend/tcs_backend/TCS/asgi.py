import os
import django
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator
from django.urls import re_path

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "TCS.settings.development")
django.setup()

from apps.chat.middleware import JWTAuthMiddlewareStack
from apps.chat.consumers import ChatConsumer
from apps.notifications.consumers import NotificationConsumer

websocket_urlpatterns = [
    re_path(r"^ws/chat/(?P<room_id>[0-9a-f-]+)/$", ChatConsumer.as_asgi()),
    re_path(r"^ws/notifications/$", NotificationConsumer.as_asgi()),
]

application = ProtocolTypeRouter({
    "http": get_asgi_application(),
    "websocket": AllowedHostsOriginValidator(
        JWTAuthMiddlewareStack(URLRouter(websocket_urlpatterns))
    ),
})
