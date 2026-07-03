from django.urls import path
from .views import ReportCreateView, BlockListCreateView, BlockDestroyView
from .staff_views import (
    report_queue, report_action, staff_overview,
    suspended_users, restore_user, staff_roster,
    wellbeing_queue, wellbeing_action, needs_attention, audit_log,
    staff_members, set_user_role, engagement_trend,
    broadcast_create, broadcast_list, broadcast_responses,
    broadcast_active, broadcast_mark_safe,
    child_safety_cases, child_safety_detail, child_safety_action,
)
from .termination_views import (
    terminate_student, termination_log, lift_termination,
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
    path("staff/roster/",                   staff_roster, name="moderation-staff-roster"),
    path("staff/wellbeing/",                wellbeing_queue, name="moderation-staff-wellbeing"),
    path("staff/wellbeing/<uuid:pk>/action/", wellbeing_action, name="moderation-staff-wellbeing-action"),
    path("staff/needs-attention/",          needs_attention, name="moderation-staff-needs"),
    path("staff/audit/",                    audit_log, name="moderation-staff-audit"),
    path("staff/members/",                  staff_members, name="moderation-staff-members"),
    path("staff/members/<uuid:pk>/role/",   set_user_role, name="moderation-staff-set-role"),
    path("staff/engagement/",               engagement_trend, name="moderation-staff-engagement"),

    # Student termination + escalation ladder's terminal action
    path("staff/terminate/",                     terminate_student, name="moderation-terminate"),
    path("staff/terminations/",                  termination_log,   name="moderation-terminations"),
    path("staff/terminations/<uuid:pk>/lift/",   lift_termination,  name="moderation-termination-lift"),

    # Child-safety routing (safeguarding leads only)
    path("staff/child-safety/",                  child_safety_cases,  name="moderation-cs-cases"),
    path("staff/child-safety/<uuid:pk>/",        child_safety_detail, name="moderation-cs-detail"),
    path("staff/child-safety/<uuid:pk>/action/", child_safety_action, name="moderation-cs-action"),

    # Emergency broadcast (elevated staff send; students acknowledge)
    path("staff/broadcast/",                  broadcast_create,    name="moderation-broadcast-create"),
    path("staff/broadcasts/",                 broadcast_list,      name="moderation-broadcast-list"),
    path("staff/broadcast/<uuid:pk>/responses/", broadcast_responses, name="moderation-broadcast-responses"),
    path("broadcast/active/",                 broadcast_active,    name="moderation-broadcast-active"),
    path("broadcast/<uuid:pk>/safe/",         broadcast_mark_safe, name="moderation-broadcast-safe"),
]
