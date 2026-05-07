# apps/feedback/admin.py
from django.contrib import admin
from .models import Suggestion


@admin.register(Suggestion)
class SuggestionAdmin(admin.ModelAdmin):
    list_display  = ['title', 'user', 'category', 'status', 'created_at']
    list_filter   = ['category', 'status']
    search_fields = ['title', 'message', 'user__name', 'user__user_id']
    readonly_fields = ['id', 'user', 'category', 'title', 'message', 'created_at']
    ordering = ['-created_at']
    list_per_page = 50

    fieldsets = (
        ('Submission', {'fields': ('id', 'user', 'category', 'title', 'message', 'created_at')}),
        ('Admin Response', {'fields': ('status', 'admin_note')}),
    )