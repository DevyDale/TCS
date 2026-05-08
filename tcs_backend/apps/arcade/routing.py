# apps/arcade/routing.py
from django.urls import re_path
from .consumers import MatchConsumer

websocket_urlpatterns = [
    re_path(r"^ws/arcade/match/(?P<session_id>[0-9a-f-]+)/$",
            MatchConsumer.as_asgi()),
]