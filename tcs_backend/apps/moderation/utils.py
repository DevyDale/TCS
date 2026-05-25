"""Helpers used by other apps to enforce blocks + content filtering."""
import re
from django.db.models import Q
from .models import Block, BlockedKeyword


def is_blocked_between(a, b):
    """
    True if EITHER user has blocked the other. Blocking severs interaction in
    both directions: a blocked person can never DM / chat-request the blocker,
    and the blocker can't re-open a chat with them without unblocking first.
    """
    if not a or not b:
        return False
    return Block.objects.filter(
        Q(blocker=a, blocked=b) | Q(blocker=b, blocked=a)
    ).exists()


def purge_chat_links(user_a, user_b):
    """
    Called right after a block is created. Removes any lingering ChatRequest
    rows between the two users (both directions) so the blocker's incoming
    requests list is clean and a stale 'declined/accepted' row can't get in
    the way. The block itself is what enforces 'can never request again' —
    this is just tidy-up. Imported lazily to avoid a hard chat→moderation dep.
    """
    if not user_a or not user_b:
        return
    try:
        from apps.chat.models import ChatRequest
        ChatRequest.objects.filter(
            Q(sender=user_a, receiver=user_b) | Q(sender=user_b, receiver=user_a)
        ).delete()
    except Exception:
        # chat app unavailable (e.g. in an isolated test) — non-fatal.
        pass


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
