# apps/notifications/announcement_tasks.py
import logging
from celery import shared_task
from django.contrib.auth import get_user_model
from .tasks import _create, _fcm_send_multi

logger = logging.getLogger(__name__)
User   = get_user_model()


@shared_task(name="push_announcement", ignore_result=True)
def push_announcement(announcement_id):
    """Fan an announcement out to its audience as in-app + FCM notifications."""
    from .models import Announcement
    a = Announcement.objects.select_related("author").filter(id=announcement_id).first()
    if not a or not a.is_published:
        return

    qs = User.objects.filter(is_active=True)
    if a.audience == "students":
        qs = qs.filter(role="student")
    elif a.audience == "staff":
        qs = qs.filter(role__in=["teaching_staff", "non_teaching_staff"])
    elif a.audience == "year_group" and a.year_group:
        qs = qs.filter(role="student", year_group=a.year_group)
    # "all" → every active user

    if a.author_id:
        qs = qs.exclude(id=a.author_id)

    title    = a.title
    body     = (a.body[:140] + "…") if len(a.body) > 140 else a.body
    actor_id = str(a.author_id) if a.author_id else None

    tokens, sent = [], 0
    for u in qs.iterator():
        try:
            _create(str(u.id), actor_id, "announcement", title, body,
                    "announcement", str(a.id))
            tok = getattr(u, "fcm_token", None)
            if tok:
                tokens.append(tok)
            sent += 1
        except Exception as e:
            logger.debug(f"announcement fan-out skip: {e}")
    # One batched multicast for all recipients instead of N serial sends.
    pushed = _fcm_send_multi(tokens, title, body,
                             {"type": "announcement", "announcement_id": str(a.id)})
    logger.info(f"push_announcement {announcement_id}: created {sent}, pushed {pushed}")
