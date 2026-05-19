"""Notify the developer about new reports — required for Apple 1.2 SLA."""
import logging
from django.core.mail import mail_admins

logger = logging.getLogger(__name__)


def notify_admin_new_report(report):
    subject = f"[TCS Moderation] New report: {report.reason}"
    body = (
        f"A new content report was filed.\n\n"
        f"Reason:      {report.reason}\n"
        f"Reporter:    {report.reporter.user_id} ({getattr(report.reporter, 'name', '')})\n"
        f"Content:     {report.content_type.model} / {report.object_id}\n"
        f"Description: {report.description or '(none)'}\n"
        f"Filed at:    {report.created_at:%Y-%m-%d %H:%M %Z}\n\n"
        f"Review in admin: /admin/moderation/report/{report.id}/change/\n\n"
        f"Apple guideline 1.2 requires action within 24 hours.\n"
    )
    try:
        mail_admins(subject, body, fail_silently=True)
    except Exception as e:
        logger.warning("mail_admins failed for report %s: %s", report.id, e)

    logger.info(
        "moderation.report id=%s reason=%s ct=%s obj=%s",
        report.id, report.reason, report.content_type.model, report.object_id,
    )
