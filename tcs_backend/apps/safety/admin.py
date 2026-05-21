from django.contrib import admin, messages
from django.utils import timezone
from django.utils.html import format_html

from .models import BlockedUser, Report


@admin.register(BlockedUser)
class BlockedUserAdmin(admin.ModelAdmin):
    list_display        = ("blocker", "blocked", "created_at")
    search_fields       = ("blocker__user_id", "blocked__user_id",
                           "blocker__name", "blocked__name")
    list_select_related = ("blocker", "blocked")
    readonly_fields     = ("created_at",)


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    """
    The moderation queue. Default sort surfaces newest first; filter by
    status='Pending review' to see the work list. The SLA column flags
    anything older than the 24-hour Apple G1.2 window in red.
    """
    list_display        = ("created_at", "status_badge", "target_type",
                           "reason", "offender", "reporter", "sla")
    list_filter         = ("status", "target_type", "reason", "created_at")
    search_fields       = ("target_id", "offender__user_id", "offender__name",
                           "reporter__user_id", "detail")
    readonly_fields     = ("created_at", "handled_at", "handled_by",
                           "target_type", "target_id", "offender", "reporter")
    list_select_related = ("offender", "reporter", "handled_by")
    actions             = ("remove_content_and_eject", "dismiss_reports")

    @admin.display(description="Status")
    def status_badge(self, obj):
        colors = {"pending": "#F7971E", "actioned": "#2E7D32", "dismissed": "#888"}
        return format_html('<b style="color:{}">{}</b>',
                           colors.get(obj.status, "#000"), obj.get_status_display())

    @admin.display(description="SLA")
    def sla(self, obj):
        if obj.is_overdue:
            return format_html('<b style="color:#FF5858">⚠ OVERDUE</b>')
        return "—"

    @admin.action(description="Remove content + eject offending user (24h action)")
    def remove_content_and_eject(self, request, queryset):
        from apps.posts.models import Post, Comment
        removed = ejected = 0
        for r in queryset:
            if r.target_type == Report.Target.POST:
                Post.objects.filter(pk=r.target_id).update(is_flagged=True)
                removed += 1
            elif r.target_type == Report.Target.COMMENT:
                Comment.objects.filter(pk=r.target_id).update(is_deleted=True)
                removed += 1
            if r.offender:
                r.offender.is_active = False
                r.offender.save(update_fields=["is_active"])
                ejected += 1
            r.status     = Report.Status.ACTIONED
            r.handled_by = request.user
            r.handled_at = timezone.now()
            r.save(update_fields=["status", "handled_by", "handled_at"])
        self.message_user(
            request,
            f"Actioned {queryset.count()} report(s): "
            f"{removed} content item(s) removed, {ejected} user(s) ejected.",
            messages.SUCCESS,
        )

    @admin.action(description="Dismiss reports (no violation found)")
    def dismiss_reports(self, request, queryset):
        n = queryset.update(status=Report.Status.DISMISSED,
                            handled_by=request.user, handled_at=timezone.now())
        self.message_user(request, f"Dismissed {n} report(s).", messages.SUCCESS)
