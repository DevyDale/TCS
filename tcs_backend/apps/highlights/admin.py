from django.contrib import admin
from .models import Highlight, HighlightItem


class HighlightItemInline(admin.TabularInline):
    model           = HighlightItem
    extra           = 0
    fields          = ("order", "media_type", "duration", "file", "created_at")
    readonly_fields = ("created_at",)


@admin.register(Highlight)
class HighlightAdmin(admin.ModelAdmin):
    list_display  = ("title", "owner", "item_count", "is_archived", "created_at")
    list_filter   = ("is_archived", "created_at")
    search_fields = ("title", "owner__user_id", "owner__name")
    inlines       = [HighlightItemInline]

    def item_count(self, obj):
        return obj.items.count()
    item_count.short_description = "Items"


@admin.register(HighlightItem)
class HighlightItemAdmin(admin.ModelAdmin):
    list_display = ("highlight", "order", "media_type", "duration", "created_at")
    list_filter  = ("media_type", "created_at")
