# apps/notifications/announcement_urls.py
from django.urls import path
from . import announcement_views as v

urlpatterns = [
    path("",                  v.announcement_list,   name="announcement-list"),
    path("create/",           v.announcement_create, name="announcement-create"),
    path("<uuid:pk>/",        v.announcement_detail, name="announcement-detail"),
    path("<uuid:pk>/edit/",   v.announcement_update, name="announcement-edit"),
    path("<uuid:pk>/delete/", v.announcement_delete, name="announcement-delete"),
    path("<uuid:pk>/pin/",    v.announcement_pin,    name="announcement-pin"),
]
