# apps/posts/urls.py
from django.urls import path
from . import views

urlpatterns = [
    # ── List / Create ─────────────────────────────────────────
    path('',                views.PostListCreateView.as_view(),  name='post-list'),

    # ── Feed ──────────────────────────────────────────────────
    path('feed/',           views.FeedView.as_view(),            name='post-feed'),

    # ── My posts + bookmarks ──────────────────────────────────
    path('mine/',           views.MyPostsView.as_view(),         name='post-mine'),
    path('bookmarks/',      views.BookmarkListView.as_view(),     name='post-bookmarks'),

    # ── Media upload (Cloudinary via CloudinaryField) ─────────
    path('upload/',         views.upload_post_media,              name='post-upload-media'),

    # ── Detail ────────────────────────────────────────────────
    path('<uuid:pk>/',      views.PostDetailView.as_view(),       name='post-detail'),

    # ── Post actions ──────────────────────────────────────────
    path('<uuid:pk>/like/',     views.like_toggle,                name='post-like'),
    path('<uuid:pk>/bookmark/', views.bookmark_toggle,            name='post-bookmark'),
    path('<uuid:pk>/share/',    views.share_post,                 name='post-share'),
    path('<uuid:pk>/flag/',     views.flag_post,                  name='post-flag'),

    # ── Comments ──────────────────────────────────────────────
    path('<uuid:pk>/comments/', views.CommentListCreateView.as_view(),
         name='post-comments'),
]