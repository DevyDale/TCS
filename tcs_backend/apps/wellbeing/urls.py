# apps/wellbeing/urls.py
from django.urls import path

from . import views

urlpatterns = [
    path("overview/",              views.overview,     name="wellbeing-overview"),
    path("cases/",                 views.cases,        name="wellbeing-cases"),
    path("cases/<uuid:pk>/",       views.case_detail,  name="wellbeing-case-detail"),
    path("cases/<uuid:pk>/action/", views.case_action, name="wellbeing-case-action"),
    path("consent/",               views.consent,      name="wellbeing-consent"),
]
