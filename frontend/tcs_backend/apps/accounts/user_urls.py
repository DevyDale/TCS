from django.urls import path
from . import views

urlpatterns = [
    path("me/",                    views.MeView.as_view(),               name="me"),
    path("me/avatar/",             views.upload_avatar,                  name="upload-avatar"),
    path("me/cover/",              views.upload_cover,                   name="upload-cover"),
    path("me/fcm-token/",          views.update_fcm_token,               name="fcm-token"),
    path("search/",                views.search_users,                   name="search-users"),
    path("suggested/",             views.SuggestedUsersView.as_view(),   name="suggested-users"),
    path("<str:user_id>/",         views.UserDetailView.as_view(),       name="user-detail"),
    path("<str:user_id>/follow/",  views.follow_toggle,                  name="follow-toggle"),
]