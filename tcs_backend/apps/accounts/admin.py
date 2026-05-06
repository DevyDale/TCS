from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html
from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display    = ["user_id", "display_name", "role", "is_verified",
                       "is_online", "level", "xp", "date_joined"]
    list_filter     = ["role", "is_verified", "is_active", "is_online"]
    search_fields   = ["user_id", "name", "preferred_name", "email"]
    ordering        = ["-date_joined"]
    readonly_fields = ["id", "last_seen", "date_joined", "xp", "level", "tokens"]

    fieldsets = (
        ("Identity",   {"fields": ("id", "user_id", "role", "name",
                                   "preferred_name", "date_of_birth", "gender")}),
        ("Contact",    {"fields": ("email", "username"), "classes": ("collapse",)}),
        ("Profile",    {"fields": ("avatar", "cover", "bio", "interests",
                                   "location", "gamer_tag"), "classes": ("collapse",)}),
        ("Gamification", {"fields": ("xp", "level", "tokens")}),
        ("Permissions",  {"fields": ("is_active", "is_verified", "is_staff",
                                     "is_superuser"), "classes": ("collapse",)}),
        ("Activity",   {"fields": ("is_online", "last_seen", "date_joined")}),
    )

    add_fieldsets = (
        (None, {"classes": ("wide",), "fields": (
            "user_id", "role", "name", "date_of_birth", "password1", "password2"
        )}),
    )

    actions = ["verify_users", "award_xp_100"]

    @admin.action(description="✅ Mark as verified")
    def verify_users(self, request, queryset):
        count = queryset.update(is_verified=True)
        self.message_user(request, f"{count} user(s) verified.")

    @admin.action(description="⚡ Award 100 XP")
    def award_xp_100(self, request, queryset):
        for user in queryset:
            user.add_xp(100)
        self.message_user(request, f"Awarded 100 XP to {queryset.count()} user(s).")
