from django.db.models.signals import m2m_changed
from django.dispatch import receiver
from django.contrib.auth import get_user_model

User = get_user_model()


@receiver(m2m_changed, sender=User.followers.through)
def on_follow(sender, instance, action, pk_set, **kwargs):
    if action == "post_add" and pk_set:
        instance.add_xp(5)
