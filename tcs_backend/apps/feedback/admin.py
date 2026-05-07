# apps/feedback/admin.py
from django.contrib import admin
from .models import Suggestion, Category


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    """
    Admins drive the suggestion picker from this page. Add a new row,
    set the emoji and gradient, give it a `sort_order`, and it shows
    up in the app on next launch.
    """
    list_display  = ['label', 'key', 'emoji', 'sort_order', 'is_active']
    list_editable = ['sort_order', 'is_active']
    list_filter   = ['is_active']
    search_fields = ['key', 'label']
    ordering      = ['sort_order', 'label']

    fieldsets = (
        ('Identity',   {'fields': ('key', 'label', 'emoji')}),
        ('Appearance', {'fields': ('gradient_from', 'gradient_to')}),
        ('Display',    {'fields': ('sort_order', 'is_active')}),
    )


@admin.register(Suggestion)
class SuggestionAdmin(admin.ModelAdmin):
    list_display  = ['title', 'user', 'category', 'status', 'created_at']
    list_filter   = ['category', 'status']
    search_fields = ['title', 'message', 'user__name', 'user__user_id']
    list_select_related = ['category', 'user']

    # Submission content is locked to preserve the audit trail —
    # only status and admin_note are editable.
    readonly_fields = ['id', 'user', 'category', 'title', 'message',
                       'created_at', 'updated_at']
    ordering        = ['-created_at']
    list_per_page   = 50

    fieldsets = (
        ('Submission', {
            'fields': ('id', 'user', 'category', 'title', 'message',
                       'created_at', 'updated_at'),
        }),
        ('Admin Response', {
            'fields': ('status', 'admin_note'),
        }),
    )