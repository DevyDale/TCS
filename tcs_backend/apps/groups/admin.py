from django.contrib import admin
from .models import Group, GroupMember, GroupMaterial


class MemberInline(admin.TabularInline):
    model         = GroupMember
    extra         = 0
    fields        = ["user", "status", "joined_at"]
    readonly_fields = ["joined_at"]


@admin.register(Group)
class GroupAdmin(admin.ModelAdmin):
    list_display    = ["name", "category", "members_count", "is_public", "is_active"]
    list_filter     = ["category", "is_public", "is_active"]
    search_fields   = ["name"]
    inlines         = [MemberInline]
    readonly_fields = ["id", "members_count", "created_at"]


@admin.register(GroupMaterial)
class GroupMaterialAdmin(admin.ModelAdmin):
    list_display    = ["title", "group", "uploaded_by", "file_size"]
    readonly_fields = ["created_at"]