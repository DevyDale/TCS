# apps/showcase/urls.py
from django.urls import path

from . import views

urlpatterns = [
    path("feed/",                    views.showcase_feed,  name="showcase-feed"),
    path("<uuid:post_id>/react/",    views.showcase_react, name="showcase-react"),
    path("ai/",                      views.showcase_ai,    name="showcase-ai"),
]
