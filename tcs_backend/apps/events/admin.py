from django.contrib import admin
from .models import Event, EventRSVP


class RSVPInline(admin.TabularInline):
    model  = EventRSVP
    extra  = 0
    fields = ["user", "created_at"]
    readonly_fields = ["created_at"]


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display  = ["title", "category", "organizer", "start_time",
                     "attendees_count", "is_featured", "is_active"]
    list_filter   = ["category", "is_featured", "is_active", "is_online"]
    search_fields = ["title", "location"]
    inlines       = [RSVPInline]
    readonly_fields = ["id", "attendees_count", "created_at"]

    actions = ["feature", "deactivate"]

    @admin.action(description="⭐ Feature")
    def feature(self, r, qs): qs.update(is_featured=True)

    @admin.action(description="🚫 Deactivate")
    def deactivate(self, r, qs): qs.update(is_active=False)
