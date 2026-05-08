# apps/clubs/urls.py
from django.urls import path
from . import views as v

urlpatterns = [
    # List + create
    path("",                v.ClubListCreateView.as_view(), name="club-list"),

    # Detail
    path("<uuid:pk>/",      v.ClubDetailView.as_view(),     name="club-detail"),

    # Membership
    path("<uuid:pk>/join/",  v.join_club,                    name="club-join"),
    path("<uuid:pk>/leave/", v.leave_club,                   name="club-leave"),

    # Members
    path("<uuid:pk>/members/", v.club_members,               name="club-members"),
    path("<uuid:pk>/members/<str:user_id>/approve/",
                               v.approve_member,             name="club-member-approve"),
    path("<uuid:pk>/members/<str:user_id>/reject/",
                               v.reject_member,              name="club-member-reject"),
    path("<uuid:pk>/members/<str:user_id>/role/",
                               v.change_member_role,         name="club-member-role"),
    path("<uuid:pk>/members/<str:user_id>/",
                               v.remove_member,              name="club-member-remove"),

    # Image uploads
    path("<uuid:pk>/cover/",   v.upload_cover,               name="club-cover"),
    path("<uuid:pk>/logo/",    v.upload_logo,                name="club-logo"),

    # Phase 6 — combined posts + events feed for a club
    path("<uuid:pk>/feed/",    v.club_feed,                  name="club-feed"),

]