# apps/feedback/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('suggest/', views.submit_suggestion, name='submit-suggestion'),
    path('mine/',    views.my_suggestions,    name='my-suggestions'),
]