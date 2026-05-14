# apps/highlights/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('',         views.HighlightListCreateView.as_view(), name='highlight-list'),
    path('feed/',    views.HighlightsFeedView.as_view(),      name='highlight-feed'),
    path('mine/',    views.MyHighlightsView.as_view(),        name='highlight-mine'),
    path('upload/',  views.upload_highlight_media,            name='highlight-upload'),

    # Per-item engagement (story-slide level likes + comments)
    path('items/<uuid:item_id>/like/',
                     views.toggle_item_like,                  name='highlight-item-like'),
    path('items/<uuid:item_id>/comments/',
                     views.HighlightItemCommentsView.as_view(), name='highlight-item-comments'),

    path('<uuid:highlight_id>/items/<uuid:pk>/',
                     views.delete_highlight_item,             name='highlight-item-delete'),
    # Keep last - the bare UUID matcher would otherwise swallow paths above.
    path('<uuid:pk>/', views.HighlightDetailView.as_view(),   name='highlight-detail'),
]
