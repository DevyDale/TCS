from django.urls import path
from . import views

urlpatterns = [
    # Rooms
    path("rooms/",                                views.RoomListCreateView.as_view(),  name="room-list"),
    path("rooms/<uuid:room_id>/",                 views.RoomDetailView.as_view(),      name="room-detail"),
    path("rooms/<uuid:room_id>/messages/",        views.message_history,               name="msg-history"),
    path("rooms/<uuid:room_id>/read/",            views.mark_room_read,                name="mark-read"),
    path("recent/",                               views.recent_chats,                  name="recent-chats"),

    # DMs
    path("dm/start/",                             views.start_dm,                      name="start-dm"),
    path("dm/search/",                            views.search_chats,                  name="chat-search"),

    # Media
    path("upload/",                               views.upload_chat_media,             name="chat-upload"),

    # Stickers / GIFs
    path("gifs/search/",                          views.gif_search,                    name="gif-search"),
    path("gifs/trending/",                        views.gif_trending,                  name="gif-trending"),
    path("stickers/",                             views.sticker_packs,                 name="sticker-packs"),

    # Chat requests
    path("requests/",                             views.chat_requests_list,            name="chat-requests"),
    path("requests/send/",                        views.send_chat_request,             name="chat-request-send"),
    path("requests/<uuid:req_id>/accept/",        views.accept_chat_request,           name="chat-request-accept"),
    path("requests/<uuid:req_id>/decline/",       views.decline_chat_request,          name="chat-request-decline"),

    # Study buddy
    path("study-buddy/",                          views.study_buddy_list,              name="study-buddy-list"),
    path("study-buddy/start/",                    views.start_study_buddy_chat,        name="study-buddy-chat"),

    # Saved materials
    path("saved/",                                views.saved_materials,               name="saved-materials"),
    path("saved/save/",                           views.save_material,                 name="save-material"),
    path("saved/<uuid:material_id>/",             views.update_saved_material,         name="update-saved"),
    path("saved/<uuid:material_id>/delete/",      views.delete_saved_material,         name="delete-saved"),
]