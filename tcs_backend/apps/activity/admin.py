from django.contrib import admin
from .models import Activity


@admin.register(Activity)
class ActivityAdmin(admin.ModelAdmin):
    list_display  = ("verb", "actor", "user", "target_name", "is_read", "created_at")
    list_filter   = ("verb", "is_read", "created_at")
    search_fields = ("target_name",)
    readonly_fields = ("id", "created_at")
