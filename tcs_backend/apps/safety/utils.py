from .models import BlockedUser


def blocked_user_ids(user):
    """
    All user PKs that should be invisible to ``user`` in feeds:
    everyone ``user`` has blocked, plus everyone who has blocked ``user``
    (blocking hides both parties from each other).

    Returns a set (possibly empty). Safe for anonymous / None users.
    """
    if not user or not getattr(user, "is_authenticated", False):
        return set()
    made = BlockedUser.objects.filter(blocker=user).values_list("blocked_id", flat=True)
    recv = BlockedUser.objects.filter(blocked=user).values_list("blocker_id", flat=True)
    return set(made) | set(recv)
