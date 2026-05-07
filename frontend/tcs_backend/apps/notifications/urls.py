from django.urls import path
from . import views

urlpatterns = [
    path("",                      views.notification_list,   name="notif-list"),
    path("unread-count/",         views.unread_count,        name="unread-count"),
    path("mark-all-read/",        views.mark_all_read,       name="mark-all-read"),
    path("clear/",                views.clear_all,           name="clear-all"),
    path("<uuid:notif_id>/read/", views.mark_read,           name="mark-read"),
    path("<uuid:notif_id>/",      views.delete_notification, name="delete-notif"),
]
