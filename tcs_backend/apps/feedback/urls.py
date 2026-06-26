# apps/feedback/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('categories/', views.list_categories,    name='categories'),
    path('suggest/',    views.submit_suggestion,  name='submit-suggestion'),
    path('mine/',       views.my_suggestions,     name='my-suggestions'),
    path('school/',     views.school_suggestions, name='school-suggestions'),
    path('staff/<uuid:pk>/',       views.staff_update_suggestion, name='staff-update-suggestion'),
    path('staff/<uuid:pk>/reply/', views.staff_reply_suggestion,  name='staff-reply-suggestion'),
]