from django.urls import path
from . import views

urlpatterns = [
    # POST blocks, DELETE unblocks — handled by one view.
    path("block/<str:user_id>/", views.block_user,    name="safety-block"),
    path("blocks/",              views.blocked_list,   name="safety-blocks"),
    path("report/",              views.report_content, name="safety-report"),
]
