from django.urls import path
from . import views

urlpatterns = [
    path("student/",                  views.register_student, name="register-student"),
    path("staff/",                    views.register_staff,   name="register-staff"),
    path("student/<str:student_id>/", views.get_student,      name="get-student"),
    path("staff/<str:staff_id>/",     views.get_staff,        name="get-staff"),
]
