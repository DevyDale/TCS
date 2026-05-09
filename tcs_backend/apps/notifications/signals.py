"""
Signal-based wiring for notification triggers.

Listens for:
  - GameRequest created           → game_request notification
  - ChatRequest created/repinged  → chat_request notification
  - Event created                 → highlight notification (fan-out)
  - Post (announcement) created   → highlight notification (fan-out)
  - GroupMember added (active)    → study_group_invite notification

Study buddy notifications are dispatched explicitly from
chat.views.start_study_buddy_chat — see the wiring instructions
at the bottom of the README.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.db import transaction


# ── GameRequest ───────────────────────────────────────────────
@receiver(post_save, sender="arcade.GameRequest")
def on_game_request(sender, instance, created, **kwargs):
    if not created or instance.status != "pending":
        return
    from .tasks import push_game_request_notification

    def _fire():
        try:
            push_game_request_notification.delay(str(instance.id))
        except Exception:
            # Celery not running — fall back to inline so dev still works
            push_game_request_notification(str(instance.id))

    transaction.on_commit(_fire)


# ── ChatRequest ───────────────────────────────────────────────
@receiver(post_save, sender="chat.ChatRequest")
def on_chat_request(sender, instance, created, **kwargs):
    # Notify on first creation OR when a previously declined request
    # is bumped back to pending.
    if instance.status != "pending":
        return
    if not created:
        # Use update_fields to detect status flips. If unavailable,
        # bail out to avoid spamming on unrelated saves.
        if "status" not in (kwargs.get("update_fields") or set()):
            return

    from .tasks import push_chat_request_notification

    def _fire():
        try:
            push_chat_request_notification.delay(str(instance.id))
        except Exception:
            push_chat_request_notification(str(instance.id))

    transaction.on_commit(_fire)


# ── Event highlight ───────────────────────────────────────────
@receiver(post_save, sender="events.Event")
def on_event_created(sender, instance, created, **kwargs):
    if not created or not instance.is_active:
        return
    from .tasks import push_highlight_notification

    actor_id = str(instance.organizer.id) if instance.organizer_id else None

    def _fire():
        try:
            push_highlight_notification.delay("event", str(instance.id), actor_id)
        except Exception:
            push_highlight_notification("event", str(instance.id), actor_id)

    transaction.on_commit(_fire)


# ── Announcement highlight ────────────────────────────────────
@receiver(post_save, sender="posts.Post")
def on_announcement_created(sender, instance, created, **kwargs):
    if not created or instance.post_type != "announcement":
        return
    from .tasks import push_highlight_notification

    actor_id = str(instance.author.id) if instance.author_id else None

    def _fire():
        try:
            push_highlight_notification.delay("announcement", str(instance.id), actor_id)
        except Exception:
            push_highlight_notification("announcement", str(instance.id), actor_id)

    transaction.on_commit(_fire)


# ── Study group invite ────────────────────────────────────────
@receiver(post_save, sender="groups.GroupMember")
def on_group_member_added(sender, instance, created, **kwargs):
    if not created or instance.status != "active":
        return
    # Don't notify the creator about themselves
    if instance.group.created_by_id == instance.user_id:
        return

    from .tasks import push_study_group_invite_notification

    # We can't always know who added them from inside a signal, so we
    # pass None — the task will produce a generic "you've been added" message.
    # If you want attribution, dispatch the task directly from
    # groups.views.add_group_member with `added_by_id=request.user.id`
    # and skip this signal for that path.
    def _fire():
        try:
            push_study_group_invite_notification.delay(
                str(instance.group_id), str(instance.user_id), None)
        except Exception:
            push_study_group_invite_notification(
                str(instance.group_id), str(instance.user_id), None)

    transaction.on_commit(_fire)