from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path("login/",          views.IDLoginView.as_view(),       name="login-id"),
    path("login-password/", views.PasswordLoginView.as_view(), name="login-password"),
    path("register/",       views.RegisterView.as_view(),      name="register"),
    path("logout/",         views.LogoutView.as_view(),        name="logout"),
    path("token/refresh/",  TokenRefreshView.as_view(),        name="token-refresh"),
    path("student/verify/", views.verify_student,              name="verify-student"),
    path("staff/verify/",   views.verify_staff,                name="verify-staff"),
]