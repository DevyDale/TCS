# apps/safety/urls.py
from django.urls import path

from . import views

urlpatterns = [
    path("emergency/",                 views.emergency_create,  name="emergency-create"),
    path("emergency/active/",          views.emergency_active,  name="emergency-active"),
    path("emergency/history/",         views.emergency_history, name="emergency-history"),
    path("emergency/<uuid:pk>/",       views.emergency_detail,  name="emergency-detail"),
    path("emergency/<uuid:pk>/update/",  views.emergency_update,  name="emergency-update"),
    path("emergency/<uuid:pk>/resolve/", views.emergency_resolve, name="emergency-resolve"),
    path("emergency/<uuid:pk>/ack/",     views.emergency_ack,     name="emergency-ack"),
    path("emergency/<uuid:pk>/roster/",  views.emergency_roster,  name="emergency-roster"),
    path("emergency/<uuid:pk>/delete/",  views.emergency_delete,  name="emergency-delete"),
]
