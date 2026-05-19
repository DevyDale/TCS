from django.urls import path
from .views import ReportCreateView, BlockListCreateView, BlockDestroyView

urlpatterns = [
    path("reports/",              ReportCreateView.as_view(),    name="moderation-report"),
    path("blocks/",               BlockListCreateView.as_view(), name="moderation-blocks"),
    path("blocks/<str:user_id>/", BlockDestroyView.as_view(),    name="moderation-unblock"),
]
