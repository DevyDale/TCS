# apps/posts/feeling_urls.py
# Mounted by TCS/urls.py at /api/feelings/.
from django.urls import path
from . import views

urlpatterns = [
    path("", views.list_feelings, name="feelings-list"),
]
