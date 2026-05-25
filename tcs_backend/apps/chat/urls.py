from django.urls import path
from . import views
from . import ai_analyze as ai_analyze_mod
from . import bubble_views

urlpatterns = [
    # Rooms
    path("rooms/",                                views.RoomListCreateView.as_view(),  name="room-list"),
    path("rooms/<uuid:room_id>/",                 views.RoomDetailView.as_view(),      name="room-detail"),
    path("rooms/<uuid:room_id>/messages/",        views.message_history,               name="msg-history"),
    path("rooms/<uuid:room_id>/read/",            views.mark_room_read,                name="mark-read"),
    path("rooms/<uuid:room_id>/avatar/", views.upload_bubble_avatar, name="bubble-avatar"),
    path("recent/",                               views.recent_chats,                  name="recent-chats"),

    # DMs
    path("dm/start/",                             views.start_dm,                      name="start-dm"),
    path("dm/search/",                            views.search_chats,                  name="chat-search"),

    path("users/online/",                        views.online_users,                  name="chat-users-online"),
    path("users/connected/",                     views.connected_users,               name="chat-users-connected"),
    # Media
    path("upload/",                               views.upload_chat_media,             name="chat-upload"),

    # Stickers / GIFs
    path("gifs/search/",                          views.gif_search,                    name="gif-search"),
    path("gifs/trending/",                        views.gif_trending,                  name="gif-trending"),
    path("stickers/",                             views.sticker_packs,                 name="sticker-packs"),

    # Chat requests
    path("requests/",                             views.chat_requests_list,            name="chat-requests"),
    path("requests/sent/",                        views.sent_chat_requests_list,       name="chat-requests-sent"),
    path("requests/send/",                        views.send_chat_request,             name="chat-request-send"),
    path("requests/<uuid:req_id>/accept/",        views.accept_chat_request,           name="chat-request-accept"),
    path("requests/<uuid:req_id>/decline/",       views.decline_chat_request,          name="chat-request-decline"),
    path("requests/<uuid:req_id>/cancel/",        views.cancel_chat_request,           name="chat-request-cancel"),

    # Study buddy
    path("study-buddy/",                          views.study_buddy_list,              name="study-buddy-list"),
    path("study-buddy/start/",                    views.start_study_buddy_chat,        name="study-buddy-chat"),

    # Saved materials
    path("saved/",                                views.saved_materials,               name="saved-materials"),
    path("saved/save/",                           views.save_material,                 name="save-material"),
    path("saved/<uuid:material_id>/",             views.update_saved_material,         name="update-saved"),
    path("saved/<uuid:material_id>/delete/",      views.delete_saved_material,         name="delete-saved"),
    path("rooms/<uuid:room_id>/ai-analyze/", ai_analyze_mod.ai_analyze_room, name="chat-ai-analyze"),
    path("rooms/<uuid:room_id>/ai/enable/",  bubble_views.enable_ai_in_room,  name="chat-ai-enable"),
    path("rooms/<uuid:room_id>/ai/summon/",  bubble_views.summon_dale,        name="chat-ai-summon"),
    path("rooms/<uuid:room_id>/ai/disable/", bubble_views.disable_ai_in_room, name="chat-ai-disable"),
]
