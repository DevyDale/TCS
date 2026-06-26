from django.urls import path
from . import views

urlpatterns = [
    path("",                                views.GroupListCreateView.as_view(),  name="group-list"),
    path("user-search/",                    views.search_users_for_group,         name="group-user-search"),
    path("<uuid:pk>/",                      views.GroupDetailView.as_view(),      name="group-detail"),
    path("<uuid:group_id>/join/",           views.join_group,                     name="group-join"),
    path("<uuid:group_id>/join-mentor/",    views.join_group_as_mentor,           name="group-join-mentor"),
    path("<uuid:group_id>/step-down-mentor/", views.step_down_mentor,             name="group-step-down-mentor"),
    path("<uuid:group_id>/leave/",          views.leave_group,                    name="group-leave"),
    path("<uuid:group_id>/members/",        views.group_members,                  name="group-members"),
    path("<uuid:group_id>/members/add/",    views.add_group_member,               name="group-member-add"),
    path("<uuid:group_id>/members/remove/", views.remove_group_member,            name="group-member-remove"),
    path("<uuid:group_id>/materials/",      views.group_materials,                name="group-materials"),
    path("<uuid:group_id>/ai/summon/",      views.summon_dale_in_group_view,      name="group-ai-summon"),
    path("buddies/",                        views.study_buddies,                  name="study-buddies"),
    path("buddies/me/",                     views.update_study_buddy,             name="update-buddy"),
    path("<uuid:group_id>/materials/<uuid:material_id>/save/",
     views.save_group_material, name="save-group-material"),
]