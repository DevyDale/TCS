from django.contrib import admin
from .models import Room, RoomMember, Message, StickerPack, Sticker


class MemberInline(admin.TabularInline):
    model  = RoomMember
    extra  = 0
    fields = ["user", "is_muted", "joined_at"]
    readonly_fields = ["joined_at"]


@admin.register(Room)
class RoomAdmin(admin.ModelAdmin):
    list_display  = ["id", "name", "room_type", "is_active", "created_at"]
    list_filter   = ["room_type", "is_active"]
    search_fields = ["name"]
    inlines       = [MemberInline]
    readonly_fields = ["id", "direct_key", "created_at"]


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display  = ["id", "room", "sender", "message_type", "is_deleted", "created_at"]
    list_filter   = ["message_type", "is_deleted"]
    search_fields = ["text", "sender__name"]
    readonly_fields = ["id", "created_at"]

    actions = ["soft_delete"]

    @admin.action(description="🗑 Soft-delete messages")
    def soft_delete(self, request, queryset):
        from django.utils import timezone
        queryset.update(is_deleted=True, deleted_at=timezone.now(),
                        text="", message_type="deleted")


class StickerInline(admin.TabularInline):
    model  = Sticker
    extra  = 0
    fields = ["name", "image", "is_animated", "sort_order"]


@admin.register(StickerPack)
class StickerPackAdmin(admin.ModelAdmin):
    list_display = ["name", "is_free", "token_cost"]
    inlines      = [StickerInline]
