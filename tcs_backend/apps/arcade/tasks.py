from celery import shared_task
import logging

logger = logging.getLogger(__name__)


@shared_task(name="expire_game_requests", ignore_result=True)
def expire_game_requests():
    from datetime import timedelta
    from django.utils import timezone
    from .models import GameRequest
    cutoff = timezone.now() - timedelta(hours=48)
    count  = GameRequest.objects.filter(status="pending", created_at__lt=cutoff).update(status="expired")
    logger.info(f"Expired {count} game request(s).")


@shared_task(name="update_group_active_counts", ignore_result=True)
def update_group_active_counts():
    from apps.groups.models import Group, GroupMember
    from django.contrib.auth import get_user_model
    User = get_user_model()
    online_ids = set(User.objects.filter(is_online=True).values_list("id", flat=True))
    for group in Group.objects.filter(is_active=True):
        member_ids = set(GroupMember.objects.filter(
            group=group, status="active").values_list("user_id", flat=True))
        active_now = len(member_ids & online_ids)
        if group.active_now != active_now:
            Group.objects.filter(pk=group.pk).update(active_now=active_now)
