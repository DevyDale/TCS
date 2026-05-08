# apps/posts/hashtag_urls.py
# Mounted by TCS/urls.py at /api/hashtags/.
from django.urls import path
from . import views

urlpatterns = [
    path("", views.list_hashtags, name="hashtags-list"),
]
