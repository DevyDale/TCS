# apps/quiz/urls.py
from django.urls import path

from . import views

urlpatterns = [
    path("",                                views.list_my_quizzes, name="quiz-list"),
    path("generate/",                       views.generate_quiz,   name="quiz-generate"),
    path("<uuid:quiz_id>/",                 views.quiz_detail,     name="quiz-detail"),
    path("<uuid:quiz_id>/play/",            views.quiz_play,       name="quiz-play"),
    path("<uuid:quiz_id>/submit/",          views.submit_attempt,  name="quiz-submit"),
    path("<uuid:quiz_id>/attempts/",        views.quiz_attempts,   name="quiz-attempts"),
]