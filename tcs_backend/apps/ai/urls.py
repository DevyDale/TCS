# apps/ai/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path("chat/",   views.ai_chat,   name="ai-chat"),
    path("status/", views.ai_status, name="ai-status"),
]
