import logging
from django.db.models.signals import pre_save, post_save, post_delete
from django.dispatch import receiver
from .models import ClubMember

log = logging.getLogger(__name__)


def _send_notification(user, action, club):
    try:
        from apps.notifications.models import Notification
    except Exception as e:
        log.warning(f"notifications app not importable: {e}")
        return
    try:
        fields = {f.name for f in Notification._meta.get_fields()}
        kw = {}
        for k in ('recipient', 'user', 'to_user'):
            if k in fields: kw[k] = user; break
        body = f"Your request to join {club.name} was {action}."
        for k in ('message', 'body', 'text'):
            if k in fields: kw[k] = body; break
        if 'title' in fields: kw['title'] = f"Club request {action}"
        for k in ('type', 'notification_type', 'kind', 'category'):
            if k in fields: kw[k] = f'club_request_{action}'; break
        if 'data' in fields: kw['data'] = {'club_id': str(club.id), 'action': action}
        Notification.objects.create(**kw)
    except Exception as e:
        log.warning(f"Failed to send club notification: {e}")


@receiver(pre_save, sender=ClubMember)
def _capture_old(sender, instance, **kwargs):
    if instance.pk:
        try: instance._old_status = sender.objects.get(pk=instance.pk).status
        except sender.DoesNotExist: instance._old_status = None
    else:
        instance._old_status = None


@receiver(post_save, sender=ClubMember)
def _on_save(sender, instance, created, **kwargs):
    if created: return
    if getattr(instance, '_old_status', None) == 'pending' and instance.status == 'active':
        _send_notification(instance.user, 'approved', instance.club)


@receiver(post_delete, sender=ClubMember)
def _on_delete(sender, instance, **kwargs):
    if instance.status == 'pending':
        _send_notification(instance.user, 'declined', instance.club)
