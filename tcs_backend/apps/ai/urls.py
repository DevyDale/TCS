# apps/ai/urls.py
from django.urls import path
from . import views
from .router_views import ai_router_status
from .knowledge_views import (knowledge_list, knowledge_upload, knowledge_upload_url,
                              knowledge_toggle, knowledge_delete,
                              knowledge_chunks, knowledge_analytics)
from .translate_views import ai_translate
from .extract_views import extract_document

urlpatterns = [
    # Text tools
    path("chat/",   views.ai_chat,   name="ai-chat"),
    path("code/",   views.ai_code,   name="ai-code"),
    path("status/", views.ai_status, name="ai-status"),
    path("birthday-note/", views.birthday_note, name="ai-birthday-note"),
    path("scam-check/",     views.scam_check,    name="ai-scam-check"),
    path("extract/",        extract_document,    name="ai-extract"),
    path("announce-assist/", views.announce_assist, name="ai-announce-assist"),
    path("about-me/", views.about_me, name="ai-about-me"),

    # Phase 1 router diagnostics (staff-only)
    path("router/", ai_router_status, name="ai-router-status"),

    # Batch UI translation (auto-localization engine)
    path("translate/", ai_translate, name="ai-translate"),

    # Phase 4 RAG knowledge base (staff-only)
    path("knowledge/",                  knowledge_list,   name="ai-knowledge-list"),
    path("knowledge/upload/",           knowledge_upload, name="ai-knowledge-upload"),
    path("knowledge/upload-url/",       knowledge_upload_url, name="ai-knowledge-upload-url"),
    path("knowledge/analytics/",        knowledge_analytics, name="ai-knowledge-analytics"),
    path("knowledge/<uuid:pk>/chunks/", knowledge_chunks, name="ai-knowledge-chunks"),
    path("knowledge/<uuid:pk>/toggle/", knowledge_toggle, name="ai-knowledge-toggle"),
    path("knowledge/<uuid:pk>/",        knowledge_delete, name="ai-knowledge-delete"),

    # Companions
    path("companions/",                                   views.companion_list,           name="ai-companion-list"),
    path("companions/<uuid:companion_id>/",               views.companion_detail,         name="ai-companion-detail"),
    path("companions/<uuid:companion_id>/chat/",          views.companion_chat,           name="ai-companion-chat"),
    path("companions/<uuid:companion_id>/conversations/", views.companion_conversations,  name="ai-companion-conversations"),

    # Conversation management (load history + delete)
    path("conversations/<uuid:conversation_id>/messages/", views.conversation_messages, name="ai-conversation-messages"),
    path("conversations/<uuid:conversation_id>/",          views.conversation_delete,   name="ai-conversation-delete"),

    # Sage — personal mentor / wellbeing companion
    path("mentor/chat/",    views.mentor_chat,    name="ai-mentor-chat"),
    path("mentor/history/", views.mentor_history, name="ai-mentor-history"),
    path("mentor/clear/",   views.mentor_clear,   name="ai-mentor-clear"),

    # Image generation
    path("image/",                  views.image_generate, name="ai-image-generate"),
    path("images/",                 views.image_history,  name="ai-image-history"),
    path("images/<uuid:image_id>/", views.image_delete,   name="ai-image-delete"),
]
