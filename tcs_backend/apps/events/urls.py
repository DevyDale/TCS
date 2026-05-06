from django.urls import path
from . import views

urlpatterns = [
    path("",                      views.EventListCreateView.as_view(), name="event-list"),
    path("mine/",                 views.my_events,                     name="my-events"),
    path("managed/",              views.teacher_events,                name="teacher-events"),
    path("<uuid:pk>/",            views.EventDetailView.as_view(),     name="event-detail"),
    path("<uuid:event_id>/rsvp/", views.rsvp_toggle,                  name="event-rsvp"),
]