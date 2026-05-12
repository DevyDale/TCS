from django.urls import path
from . import views

urlpatterns = [
    path("",             views.ActivityListView.as_view(), name="activity-list"),
    path("mark-read/",   views.mark_all_read,              name="activity-mark-read"),
    path("unread-count/", views.unread_count,              name="activity-unread"),
]
