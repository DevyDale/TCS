# apps/ai/urls.py
from django.urls import path
from . import views

urlpatterns = [
    # Text tools
    path("chat/",   views.ai_chat,   name="ai-chat"),
    path("code/",   views.ai_code,   name="ai-code"),
    path("status/", views.ai_status, name="ai-status"),

    # Companions
    path("companions/",                                   views.companion_list,           name="ai-companion-list"),
    path("companions/<uuid:companion_id>/",               views.companion_detail,         name="ai-companion-detail"),
    path("companions/<uuid:companion_id>/chat/",          views.companion_chat,           name="ai-companion-chat"),
    path("companions/<uuid:companion_id>/conversations/", views.companion_conversations,  name="ai-companion-conversations"),

    # Conversation management (load history + delete)
    path("conversations/<uuid:conversation_id>/messages/", views.conversation_messages, name="ai-conversation-messages"),
    path("conversations/<uuid:conversation_id>/",          views.conversation_delete,   name="ai-conversation-delete"),

    # Image generation
    path("image/",                  views.image_generate, name="ai-image-generate"),
    path("images/",                 views.image_history,  name="ai-image-history"),
    path("images/<uuid:image_id>/", views.image_delete,   name="ai-image-delete"),
]