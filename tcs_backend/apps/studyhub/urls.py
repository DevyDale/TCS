# apps/studyhub/urls.py
from django.urls import path

from . import views

urlpatterns = [
    # Resources
    path("resources/",                    views.resources),
    path("resources/<uuid:pk>/",          views.resource_delete),
    path("resources/<uuid:pk>/verify/",   views.resource_verify),
    path("resources/<uuid:pk>/download/", views.resource_download),
    # Q&A
    path("questions/",                    views.questions),
    path("questions/<uuid:pk>/",          views.question_detail),
    path("questions/<uuid:pk>/answer/",   views.question_answer),
    path("questions/<uuid:pk>/resolve/",  views.question_resolve),
    path("questions/<uuid:pk>/upvote/",   views.question_upvote),
    path("answers/<uuid:pk>/accept/",     views.answer_accept),
    path("answers/<uuid:pk>/upvote/",     views.answer_upvote),
    # Office hours
    path("teachers/",                     views.teachers),
    path("teachers/me/",                  views.my_availability),
]
