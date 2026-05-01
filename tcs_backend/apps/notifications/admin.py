from django.contrib import admin
from .models import Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display  = ["id", "recipient", "notif_type", "title", "is_read", "created_at"]
    list_filter   = ["notif_type", "is_read"]
    search_fields = ["recipient__name", "title", "body"]
    readonly_fields = ["id", "created_at"]

    actions = ["mark_as_read"]

    @admin.action(description="✅ Mark as read")
    def mark_as_read(self, request, queryset):
        queryset.update(is_read=True)
