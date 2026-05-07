# apps/events/urls.py
from django.urls import path
from . import views

urlpatterns = [
    # ── List / Create / Detail ────────────────────────────────
    path("",                        views.EventListCreateView.as_view(), name="event-list"),
    path("highlights/",             views.campus_highlights,             name="event-highlights"),
    path("mine/",                   views.my_events,                     name="my-events"),
    path("managed/",                views.teacher_events,                name="teacher-events"),
    path("<uuid:pk>/",              views.EventDetailView.as_view(),     name="event-detail"),

    # ── RSVP — 3-state (Phase 2) ──────────────────────────────
    path("<uuid:event_id>/rsvp/",         views.rsvp_set,    name="event-rsvp"),
    # Legacy alias kept for clients that still call the old toggle endpoint.
    path("<uuid:event_id>/rsvp/toggle/",  views.rsvp_toggle, name="event-rsvp-toggle"),

    # ── Poster upload (Phase 2 spec 10.2) ─────────────────────
    path("<uuid:event_id>/poster/", views.upload_event_poster, name="event-poster"),
]
