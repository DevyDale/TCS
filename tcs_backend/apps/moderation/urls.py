from django.urls import path
from .views import ReportCreateView, BlockListCreateView, BlockDestroyView
from .staff_views import (
    report_queue, report_action, staff_overview,
    suspended_users, restore_user,
)

urlpatterns = [
    path("reports/",              ReportCreateView.as_view(),    name="moderation-report"),
    path("blocks/",               BlockListCreateView.as_view(), name="moderation-blocks"),
    path("blocks/<str:user_id>/", BlockDestroyView.as_view(),    name="moderation-unblock"),

    # Staff moderation (reports queue + triage actions)
    path("staff/reports/",                  report_queue,  name="moderation-staff-queue"),
    path("staff/reports/<uuid:pk>/action/", report_action, name="moderation-staff-action"),
    path("staff/overview/",                 staff_overview, name="moderation-staff-overview"),
    path("staff/suspended/",                suspended_users, name="moderation-staff-suspended"),
    path("staff/suspended/<uuid:pk>/restore/", restore_user, name="moderation-staff-restore"),
]
