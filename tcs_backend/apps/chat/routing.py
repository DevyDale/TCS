# apps/chat/routing.py
from django.urls import re_path
from .consumers     import ChatConsumer       # existing per-room consumer
from .list_consumer import ChatListConsumer   # NEW

websocket_urlpatterns = [
    re_path(r"ws/rooms/(?P<room_id>[^/]+)/$", ChatConsumer.as_asgi()),
    re_path(r"ws/chat-list/$",                ChatListConsumer.as_asgi()),  # NEW
]