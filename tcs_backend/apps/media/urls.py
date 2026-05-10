"""URL routes for the media app."""
from django.urls import path
from . import views

urlpatterns = [
    path("upload/",          views.upload_media, name="media-upload"),
    path("<uuid:asset_id>/", views.delete_media, name="media-delete"),
]
