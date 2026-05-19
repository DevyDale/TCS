from django.contrib import admin, messages
from django.utils import timezone
from .models import Report, Block, BlockedKeyword


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display  = ("created_at", "reason", "status", "content_type", "object_id", "reporter")
    list_filter   = ("status", "reason", "created_at")
    search_fields = ("description", "reporter__user_id", "object_id")
    readonly_fields = ("reporter", "content_type", "object_id", "reason", "description", "created_at")
    actions = ["mark_actioned", "mark_dismissed", "mark_reviewed"]

    def _bulk(self, request, qs, new_status, msg):
        n = qs.update(status=new_status, reviewed_at=timezone.now(), reviewed_by=request.user)
        self.message_user(request, f"{n} report(s) {msg}.", level=messages.SUCCESS)

    @admin.action(description="Mark as actioned (content removed)")
    def mark_actioned(self, request, qs):
        self._bulk(request, qs, Report.Status.ACTIONED, "marked actioned")

    @admin.action(description="Dismiss reports")
    def mark_dismissed(self, request, qs):
        self._bulk(request, qs, Report.Status.DISMISSED, "dismissed")

    @admin.action(description="Mark reviewed (no action)")
    def mark_reviewed(self, request, qs):
        self._bulk(request, qs, Report.Status.REVIEWED, "marked reviewed")


@admin.register(Block)
class BlockAdmin(admin.ModelAdmin):
    list_display  = ("created_at", "blocker", "blocked", "reason")
    list_filter   = ("reason", "created_at")
    search_fields = ("blocker__user_id", "blocked__user_id")


@admin.register(BlockedKeyword)
class BlockedKeywordAdmin(admin.ModelAdmin):
    list_display  = ("keyword", "severity", "created_at")
    list_filter   = ("severity",)
    search_fields = ("keyword",)
