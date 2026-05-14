# apps/highlights/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('',         views.HighlightListCreateView.as_view(), name='highlight-list'),
    path('mine/',    views.MyHighlightsView.as_view(),        name='highlight-mine'),
    path('upload/',  views.upload_highlight_media,            name='highlight-upload'),
    path('<uuid:highlight_id>/items/<uuid:pk>/',
                     views.delete_highlight_item,             name='highlight-item-delete'),
    # Keep last - the bare UUID matcher would otherwise swallow paths above.
    path('<uuid:pk>/', views.HighlightDetailView.as_view(),   name='highlight-detail'),
]
