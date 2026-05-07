# apps/clubs/admin.py
from django.contrib import admin
from .models import Club, ClubMember


class ClubMemberInline(admin.TabularInline):
    model           = ClubMember
    extra           = 0
    fields          = ["user", "status", "role", "joined_at"]
    readonly_fields = ["joined_at"]


@admin.register(Club)
class ClubAdmin(admin.ModelAdmin):
    list_display    = ["name", "category", "members_count",
                       "is_public", "is_verified", "is_active"]
    list_filter     = ["category", "is_public",
                       "is_verified", "is_active"]
    search_fields   = ["name", "tagline", "description"]
    readonly_fields = ["id", "members_count", "created_at", "updated_at"]
    inlines         = [ClubMemberInline]
    fieldsets       = (
        ("Identity", {
            "fields": ("id", "name", "tagline", "category"),
        }),
        ("Content", {
            "fields": ("description", "purpose", "mission", "rules"),
        }),
        ("Imagery", {
            "fields": ("logo", "cover", "theme_icon"),
        }),
        ("Contact", {
            "fields": ("contact_email", "contact_phone"),
        }),
        ("Settings", {
            "fields": ("is_public", "requires_approval",
                       "is_verified", "is_active"),
        }),
        ("People & stats", {
            "fields": ("created_by", "members_count"),
        }),
        ("Lifecycle", {
            "fields": ("dissolved_at", "dissolve_reason",
                       "created_at", "updated_at"),
        }),
    )


@admin.register(ClubMember)
class ClubMemberAdmin(admin.ModelAdmin):
    list_display    = ["club", "user", "role", "status", "joined_at"]
    list_filter     = ["role", "status"]
    search_fields   = ["club__name", "user__display_name", "user__user_id"]
    readonly_fields = ["joined_at"]