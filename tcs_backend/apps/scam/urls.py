# apps/scam/urls.py
from django.urls import path

from . import views

urlpatterns = [
    # Student
    path("report/", views.scam_report, name="scam-report"),
    path("alerts/", views.scam_alerts, name="scam-alerts"),
    # Staff
    path("staff/reports/",            views.staff_reports,       name="scam-staff-reports"),
    path("staff/reports/<uuid:pk>/action/", views.staff_report_action, name="scam-staff-report-action"),
    path("staff/alerts/",             views.staff_alerts,        name="scam-staff-alerts"),
    path("staff/blocklist/",          views.staff_blocklist,     name="scam-staff-blocklist"),
]
