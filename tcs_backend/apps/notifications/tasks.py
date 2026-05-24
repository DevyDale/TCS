import logging
from celery import shared_task
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)
User   = get_user_model()

# ── Firebase (lazy init) ──────────────────────────────────────
_firebase_app = None

def _fcm_send(token, title, body, data=None, badge=None):
    """Send FCM push — silently skips if Firebase not configured."""
    if not token:
        return
    try:
        global _firebase_app
        from django.conf import settings as s
        cred_path = getattr(s, "FIREBASE_CREDENTIALS_JSON", "")
        if not cred_path:
            return
        if _firebase_app is None:
            import firebase_admin
            from firebase_admin import credentials
            _firebase_app = firebase_admin.initialize_app(credentials.Certificate(cred_path))
        from firebase_admin import messaging
        messaging.send(messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={str(k): str(v) for k, v in (data or {}).items()},
            token=token,
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(aps=messaging.Aps(sound="default", badge=badge))
            ),
        ))
    except Exception as e:
        logger.debug(f"FCM skipped: {e}")


def _unread(user_id):
    """Unread notification count for the app-icon badge."""
    from .models import Notification
    try:
        return Notification.objects.filter(
            recipient_id=user_id, is_read=False).count()
    except Exception:
        return None


def _create(recipient_id, actor_id, notif_type, title, body,
            target_type="", target_id=""):
    """Create in-app Notification + push to WS channel."""
    from .models import Notification
    try:
        recipient = User.objects.get(id=recipient_id)
        actor     = User.objects.filter(id=actor_id).first() if actor_id else None

        notif = Notification.objects.create(
            recipient=recipient, actor=actor,
            notif_type=notif_type, title=title, body=body,
            target_type=target_type, target_id=str(target_id),
        )

        # WebSocket fan-out
        try:
            from channels.layers import get_channel_layer
            from asgiref.sync import async_to_sync
            group = f"notif_{str(recipient_id).replace('-', '_')}"
            async_to_sync(get_channel_layer().group_send)(group, {
                "type":        "send.notification",
                "id":          str(notif.id),
                "notif_type":  notif_type,
                "title":       title,
                "body":        body,
                "actor_name":  actor.display_name if actor else None,
                "target_type": target_type,
                "target_id":   str(target_id),
                "created_at":  notif.created_at.isoformat(),
            })
        except Exception:
            pass  # WS layer unavailable (dev mode)

        return notif
    except User.DoesNotExist:
        return None


# ── Tasks ─────────────────────────────────────────────────────

@shared_task(name="push_like_notification", ignore_result=True)
def push_like_notification(post_id, liker_id):
    from apps.posts.models import Post
    try:
        post  = Post.objects.select_related("author").get(id=post_id)
        liker = User.objects.get(id=liker_id)
        if str(post.author.id) == str(liker_id):
            return
        title = "New like on your post"
        body  = f"{liker.display_name} liked your post."
        notif = _create(str(post.author.id), liker_id, "like", title, body,
                        "post", post_id)
        if notif:
            _fcm_send(post.author.fcm_token, title, body, {"type": "like", "post_id": str(post_id)}, badge=_unread(post.author.id))
    except Exception as e:
        logger.error(f"push_like_notification: {e}")


@shared_task(name="push_comment_notification", ignore_result=True)
def push_comment_notification(comment_id):
    from apps.posts.models import Comment
    try:
        c = Comment.objects.select_related("author", "post__author").get(id=comment_id)
        if c.author == c.post.author:
            return
        title = "New comment on your post"
        body  = f"{c.author.display_name}: {c.text[:80]}"
        notif = _create(str(c.post.author.id), str(c.author.id), "comment",
                        title, body, "post", str(c.post.id))
        if notif:
            _fcm_send(c.post.author.fcm_token, title, body,
                      {"type": "comment", "post_id": str(c.post.id)}, badge=_unread(c.post.author.id))
    except Exception as e:
        logger.error(f"push_comment_notification: {e}")


@shared_task(name="push_follow_notification", ignore_result=True)
def push_follow_notification(follower_id, target_id):
    try:
        follower = User.objects.get(id=follower_id)
        target   = User.objects.get(id=target_id)
        title    = "New follower"
        body     = f"{follower.display_name} started following you."
        notif = _create(target_id, follower_id, "follow", title, body,
                        "user", follower_id)
        if notif:
            _fcm_send(target.fcm_token, title, body,
                      {"type": "follow", "user_id": str(follower_id)}, badge=_unread(target.id))
    except Exception as e:
        logger.error(f"push_follow_notification: {e}")


@shared_task(name="push_chat_notification", ignore_result=True)
def push_chat_notification(message_id, room_id):
    from apps.chat.models import Message, RoomMember
    try:
        msg     = Message.objects.select_related("sender", "room").get(id=message_id)
        members = RoomMember.objects.filter(
            room_id=room_id, is_muted=False
        ).exclude(user=msg.sender).select_related("user")

        title = msg.sender.display_name if msg.sender else "StudentHub"
        body  = msg.display_text

        for m in members:
            _create(str(m.user.id), str(msg.sender.id) if msg.sender else None,
                    "chat_message", title, body, "room", str(room_id))
            _fcm_send(m.user.fcm_token, title, body,
                      {"type": "chat", "room_id": str(room_id),
                       "message_id": str(message_id)}, badge=_unread(m.user.id))
    except Exception as e:
        logger.error(f"push_chat_notification: {e}")

# REPLACE the existing push_game_request_notification with this fixed version
@shared_task(name="push_game_request_notification", ignore_result=True)
def push_game_request_notification(request_id):
    from apps.arcade.models import GameRequest
    try:
        gr = GameRequest.objects.select_related("sender", "receiver").get(id=request_id)
        title = "Game request! 🎮"
        body  = (f"{gr.sender.display_name} challenged you to {gr.game_name} "
                 f"for 🪙 {gr.wager}!")
        notif = _create(str(gr.receiver.id), str(gr.sender.id), "game_request",
                        title, body, "game_request", str(gr.id))
        if notif:
            _fcm_send(gr.receiver.fcm_token, title, body,
                      {"type": "game_request", "request_id": str(gr.id)})
    except Exception as e:
        logger.error(f"push_game_request_notification: {e}")


# NEW — Chat request
@shared_task(name="push_chat_request_notification", ignore_result=True)
def push_chat_request_notification(request_id):
    from apps.chat.models import ChatRequest
    try:
        cr = ChatRequest.objects.select_related("sender", "receiver").get(id=request_id)
        title = "New chat request 💬"
        preview = cr.message.strip()[:80] if cr.message else "wants to chat with you"
        body  = f"{cr.sender.display_name}: {preview}"
        notif = _create(str(cr.receiver.id), str(cr.sender.id), "chat_request",
                        title, body, "chat_request", str(cr.id))
        if notif:
            _fcm_send(cr.receiver.fcm_token, title, body,
                      {"type": "chat_request", "request_id": str(cr.id)})
    except Exception as e:
        logger.error(f"push_chat_request_notification: {e}")


# NEW — Highlight (event OR announcement post). Fans out to all active users.
@shared_task(name="push_highlight_notification", ignore_result=True)
def push_highlight_notification(kind, target_id, actor_id=None):
    """
    kind: 'event' | 'announcement'
    target_id: Event UUID or Post UUID
    actor_id: organizer/author (excluded from recipients)
    """
    try:
        if kind == "event":
            from apps.events.models import Event
            obj   = Event.objects.select_related("organizer").get(id=target_id)
            title = f"📣 New event: {obj.title[:60]}"
            body  = (obj.description[:120] + "…") if len(obj.description) > 120 else obj.description
            target_type = "event"
        else:  # announcement
            from apps.posts.models import Post
            obj   = Post.objects.select_related("author").get(id=target_id)
            title = f"📢 Announcement from {obj.author.display_name}"
            body  = (obj.content[:140] + "…") if len(obj.content) > 140 else obj.content
            target_type = "announcement"

        recipients = User.objects.filter(is_active=True)
        if actor_id:
            recipients = recipients.exclude(id=actor_id)

        # Bulk insert in chunks to avoid hammering the WS layer
        from .models import Notification
        from channels.layers import get_channel_layer
        from asgiref.sync import async_to_sync
        layer = None
        try:
            layer = get_channel_layer()
        except Exception:
            pass

        bulk = []
        for u in recipients.iterator(chunk_size=500):
            bulk.append(Notification(
                recipient=u, actor_id=actor_id, notif_type="highlight",
                title=title, body=body,
                target_type=target_type, target_id=str(target_id),
            ))
            if len(bulk) >= 500:
                Notification.objects.bulk_create(bulk, ignore_conflicts=True)
                _fanout_ws(layer, bulk, title, body, target_type, target_id, actor_id)
                bulk = []
        if bulk:
            Notification.objects.bulk_create(bulk, ignore_conflicts=True)
            _fanout_ws(layer, bulk, title, body, target_type, target_id, actor_id)
    except Exception as e:
        logger.error(f"push_highlight_notification: {e}")


def _fanout_ws(layer, notifs, title, body, target_type, target_id, actor_id):
    """Helper — push the just-created notifications to each recipient's WS group."""
    if not layer:
        return
    from asgiref.sync import async_to_sync
    actor_name = None
    if actor_id:
        try:
            actor_name = User.objects.get(id=actor_id).display_name
        except User.DoesNotExist:
            pass
    for n in notifs:
        group = f"notif_{str(n.recipient_id).replace('-', '_')}"
        try:
            async_to_sync(layer.group_send)(group, {
                "type":        "send.notification",
                "id":          str(n.id),
                "notif_type":  "highlight",
                "title":       title,
                "body":        body,
                "actor_name":  actor_name,
                "target_type": target_type,
                "target_id":   str(target_id),
                "created_at":  n.created_at.isoformat() if n.created_at else None,
            })
        except Exception:
            pass


# NEW — Study buddy request
@shared_task(name="push_study_buddy_request_notification", ignore_result=True)
def push_study_buddy_request_notification(buddy_id, inviter_id, subject=""):
    try:
        buddy   = User.objects.get(id=buddy_id)
        inviter = User.objects.get(id=inviter_id)
        title = "📚 New study buddy request"
        body  = f"{inviter.display_name} wants to study"
        if subject:
            body += f" {subject}"
        body += " with you!"
        notif = _create(str(buddy_id), str(inviter_id), "study_buddy_request",
                        title, body, "user", str(inviter.user_id))
        if notif:
            _fcm_send(buddy.fcm_token, title, body,
                      {"type": "study_buddy_request",
                       "user_id": str(inviter.user_id)})
    except Exception as e:
        logger.error(f"push_study_buddy_request_notification: {e}")


# NEW — Study group invite (added to a group)
@shared_task(name="push_study_group_invite_notification", ignore_result=True)
def push_study_group_invite_notification(group_id, user_id, added_by_id=None):
    from apps.groups.models import Group
    try:
        group = Group.objects.get(id=group_id)
        user  = User.objects.get(id=user_id)
        added_by = (User.objects.filter(id=added_by_id).first()
                    if added_by_id else None)
        title = f"👥 Added to {group.name}"
        if added_by:
            body = f"{added_by.display_name} added you to the study group “{group.name}”."
        else:
            body = f"You've been added to the study group “{group.name}”."
        notif = _create(str(user_id), str(added_by_id) if added_by_id else None,
                        "study_group_invite", title, body,
                        "group", str(group_id))
        if notif:
            _fcm_send(user.fcm_token, title, body,
                      {"type": "study_group_invite", "group_id": str(group_id)})
    except Exception as e:
        logger.error(f"push_study_group_invite_notification: {e}")
@shared_task(name="push_event_reminders", ignore_result=True)
def push_event_reminders():
    from datetime import timedelta
    from django.utils import timezone
    from apps.events.models import EventRSVP
    window_start = timezone.now() + timedelta(minutes=55)
    window_end   = timezone.now() + timedelta(minutes=65)
    rsvps = EventRSVP.objects.filter(
        event__start_time__range=(window_start, window_end),
        event__is_active=True,
    ).select_related("user", "event")
    for rsvp in rsvps:
        title = f"Starting soon: {rsvp.event.title}"
        body  = f"Your event starts in ~1 hour at {rsvp.event.location}"
        _create(str(rsvp.user.id), None, "event_reminder", title, body,
                "event", str(rsvp.event.id))
        _fcm_send(rsvp.user.fcm_token, title, body,
                  {"type": "event_reminder", "event_id": str(rsvp.event.id)}, badge=_unread(rsvp.user.id))
