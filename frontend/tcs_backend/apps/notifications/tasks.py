import logging
from celery import shared_task
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)
User   = get_user_model()

# ── Firebase (lazy init) ──────────────────────────────────────
_firebase_app = None

def _fcm_send(token, title, body, data=None):
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
                payload=messaging.APNSPayload(aps=messaging.Aps(sound="default"))
            ),
        ))
    except Exception as e:
        logger.debug(f"FCM skipped: {e}")


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
            _fcm_send(post.author.fcm_token, title, body, {"type": "like", "post_id": str(post_id)})
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
                      {"type": "comment", "post_id": str(c.post.id)})
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
                      {"type": "follow", "user_id": str(follower_id)})
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
                       "message_id": str(message_id)})
    except Exception as e:
        logger.error(f"push_chat_notification: {e}")


@shared_task(name="push_game_request_notification", ignore_result=True)
def push_game_request_notification(request_id):
    from apps.arcade.models import GameRequest
    try:
        gr    = GameRequest.objects.select_related("from_user", "to_user", "game").get(id=request_id)
        title = "Game request! 🎮"
        body  = f"{gr.from_user.display_name} challenged you to {gr.game.name}!"
        notif = _create(str(gr.to_user.id), str(gr.from_user.id), "game_request",
                        title, body, "game_request", str(gr.id))
        if notif:
            _fcm_send(gr.to_user.fcm_token, title, body,
                      {"type": "game_request", "request_id": str(request_id)})
    except Exception as e:
        logger.error(f"push_game_request_notification: {e}")


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
                  {"type": "event_reminder", "event_id": str(rsvp.event.id)})
