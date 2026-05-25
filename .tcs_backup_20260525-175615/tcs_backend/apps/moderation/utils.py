"""Helpers used by other apps to enforce blocks + content filtering."""
import re
from .models import Block, BlockedKeyword


def get_blocked_user_ids(user):
    """IDs the user has blocked. Used to filter feeds / lists."""
    if not user or not user.is_authenticated:
        return set()
    return set(
        Block.objects.filter(blocker=user).values_list("blocked_id", flat=True)
    )


def filter_blocked_users(queryset, user, author_field="author"):
    """Exclude content authored by users the requester has blocked."""
    blocked_ids = get_blocked_user_ids(user)
    if not blocked_ids:
        return queryset
    return queryset.exclude(**{f"{author_field}_id__in": blocked_ids})


def contains_blocked_keyword(text):
    """Returns the matching keyword if `text` contains a 'reject' keyword."""
    if not text:
        return None
    lowered = text.lower()
    for kw in BlockedKeyword.objects.filter(severity="reject"):
        if re.search(rf"\b{re.escape(kw.keyword.lower())}\b", lowered):
            return kw.keyword
    return None
