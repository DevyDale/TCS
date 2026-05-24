import logging
from celery import shared_task
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)
User   = get_user_model()

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


# ── Posts: like / comment ─────────────────────────────────────

@shared_task(name="push_like_notification", ignore_result=True)
def push_like_notification(post_id, liker_id):
    from apps.posts.models import Post
    try:
        post  = Post.objects.select_related("author").get(id=post_id)
        liker = User.objects.get(id=liker_id)
        if str(post.author.id) == str(liker_id):
            return
        kind  = "fweet" if post.post_type == "fweet" else "post"
        title = f"New like on your {kind}"
        body  = f"{liker.display_name} liked your {kind}."
        notif = _create(str(post.author.id), liker_id, "like", title, body,
                        "post", post_id)
        if notif:
            _fcm_send(post.author.fcm_token, title, body,
                      {"type": "like", "post_id": str(post_id)})
    except Exception as e:
        logger.error(f"push_like_notification: {e}")


@shared_task(name="push_comment_notification", ignore_result=True)
def push_comment_notification(comment_id):
    from apps.posts.models import Comment
    try:
        c = Comment.objects.select_related("author", "post__author").get(id=comment_id)
        if c.author == c.post.author:
            return
        kind  = "fweet" if c.post.post_type == "fweet" else "post"
        title = f"New comment on your {kind}"
        body  = f"{c.author.display_name}: {c.text[:80]}"
        notif = _create(str(c.post.author.id), str(c.author.id), "comment",
                        title, body, "post", str(c.post.id))
        if notif:
            _fcm_send(c.post.author.fcm_token, title, body,
                      {"type": "comment", "post_id": str(c.post.id)})
    except Exception as e:
        logger.error(f"push_comment_notification: {e}")


# ── Follow ────────────────────────────────────────────────────

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


# ── Direct / group chat messages ──────────────────────────────

@shared_task(name="push_chat_notification", ignore_result=True)
def push_chat_notification(message_id, room_id):
    from apps.chat.models import Message, RoomMember
    try:
        msg     = Message.objects.select_related("sender", "room").get(id=message_id)
        members = RoomMember.objects.filter(
            room_id=room_id, is_muted=False
        ).exclude(user=msg.sender).select_related("user")

        title = msg.sender.display_name if msg.sender else "TCS"
        body  = msg.display_text

        for m in members:
            _create(str(m.user.id), str(msg.sender.id) if msg.sender else None,
                    "chat_message", title, body, "room", str(room_id))
            _fcm_send(m.user.fcm_token, title, body,
                      {"type": "chat", "room_id": str(room_id),
                       "message_id": str(message_id)})
    except Exception as e:
        logger.error(f"push_chat_notification: {e}")


# ── Chat requests: received / accepted / declined ─────────────

@shared_task(name="push_chat_request_notification", ignore_result=True)
def push_chat_request_notification(request_id):
    from apps.chat.models import ChatRequest
    try:
        req = ChatRequest.objects.select_related("sender", "receiver").get(id=request_id)
        title = "New chat request"
        body  = f"{req.sender.display_name} wants to chat with you."
        notif = _create(str(req.receiver.id), str(req.sender.id), "chat_request",
                        title, body, "chat_request", str(req.id))
        if notif:
            _fcm_send(req.receiver.fcm_token, title, body,
                      {"type": "chat_request", "request_id": str(req.id)})
    except Exception as e:
        logger.error(f"push_chat_request_notification: {e}")


@shared_task(name="push_chat_request_response_notification", ignore_result=True)
def push_chat_request_response_notification(sender_id, responder_id, accepted, room_id=""):
    """Notify the ORIGINAL sender that their request was accepted/declined."""
    try:
        responder      = User.objects.filter(id=responder_id).first()
        responder_name = responder.display_name if responder else "Someone"
        if accepted:
            notif_type, title = "request_accepted", "Chat request accepted"
            body = f"{responder_name} accepted your chat request."
            target_type, target_id = (("room", str(room_id)) if room_id
                                       else ("user", str(responder_id)))
        else:
            notif_type, title = "request_declined", "Chat request declined"
            body = f"{responder_name} declined your chat request."
            target_type, target_id = "user", str(responder_id)

        notif = _create(str(sender_id), str(responder_id), notif_type,
                        title, body, target_type, target_id)
        if notif:
            recipient = User.objects.filter(id=sender_id).first()
            if recipient:
                _fcm_send(recipient.fcm_token, title, body, {"type": notif_type})
    except Exception as e:
        logger.error(f"push_chat_request_response_notification: {e}")


# ── Added to a chat group or study group ──────────────────────

@shared_task(name="push_group_add_notification", ignore_result=True)
def push_group_add_notification(added_user_id, actor_id, group_name,
                                target_type, target_id):
    """target_type == 'group' → study group, 'room' → group chat bubble."""
    try:
        if str(added_user_id) == str(actor_id):
            return
        actor      = User.objects.filter(id=actor_id).first() if actor_id else None
        actor_name = actor.display_name if actor else "Someone"
        label      = "study group" if target_type == "group" else "group chat"
        title = f"Added to {group_name}"
        body  = f"{actor_name} added you to the {label} \u201c{group_name}\u201d."
        notif = _create(str(added_user_id), str(actor_id) if actor_id else None,
                        "group_add", title, body, target_type, str(target_id))
        if notif:
            recipient = User.objects.filter(id=added_user_id).first()
            if recipient:
                _fcm_send(recipient.fcm_token, title, body,
                          {"type": "group_add", "target_type": target_type,
                           "target_id": str(target_id)})
    except Exception as e:
        logger.error(f"push_group_add_notification: {e}")


# ── New message in a study group (a Post scoped to a group) ───

@shared_task(name="push_group_post_notification", ignore_result=True)
def push_group_post_notification(post_id):
    from apps.posts.models import Post
    from apps.groups.models import GroupMember
    try:
        post = Post.objects.select_related("author", "group").get(id=post_id)
        if not getattr(post, "group_id", None):
            return
        author  = post.author
        members = GroupMember.objects.filter(
            group_id=post.group_id, status="active"
        ).exclude(user=author).select_related("user")
        title = f"New message in {post.group.name}"
        body  = f"{author.display_name}: {(post.content or '')[:80]}"
        for m in members:
            _create(str(m.user.id), str(author.id), "group_message",
                    title, body, "group", str(post.group_id))
            _fcm_send(m.user.fcm_token, title, body,
                      {"type": "group_message", "group_id": str(post.group_id),
                       "post_id": str(post.id)})
    except Exception as e:
        logger.error(f"push_group_post_notification: {e}")


# ── New material uploaded in a study group ────────────────────

@shared_task(name="push_group_material_notification", ignore_result=True)
def push_group_material_notification(material_id):
    from apps.groups.models import GroupMaterial, GroupMember
    try:
        mat     = GroupMaterial.objects.select_related("group", "uploaded_by").get(id=material_id)
        group   = mat.group
        actor   = mat.uploaded_by
        members = GroupMember.objects.filter(
            group=group, status="active"
        ).exclude(user=actor).select_related("user")
        title = f"New material in {group.name}"
        body  = f"{actor.display_name} uploaded \u201c{mat.title}\u201d."
        for m in members:
            _create(str(m.user.id), str(actor.id), "group_material",
                    title, body, "group", str(group.id))
            _fcm_send(m.user.fcm_token, title, body,
                      {"type": "group_material", "group_id": str(group.id),
                       "material_id": str(mat.id)})
    except Exception as e:
        logger.error(f"push_group_material_notification: {e}")


# ── Club posts an event ───────────────────────────────────────

@shared_task(name="push_club_event_notification", ignore_result=True)
def push_club_event_notification(event_id):
    from apps.events.models import Event
    from apps.clubs.models import ClubMember
    try:
        event   = Event.objects.select_related("organizer").get(id=event_id)
        club_id = getattr(event, "club_id", None)
        if not club_id:
            return
        organizer = event.organizer
        members = ClubMember.objects.filter(
            club_id=club_id, status="active"
        ).exclude(user=organizer).select_related("user", "club")
        for m in members:
            title = f"New event from {m.club.name}"
            body  = f"{event.title} — {event.location}"
            _create(str(m.user.id), str(organizer.id) if organizer else None,
                    "club_event", title, body, "event", str(event.id))
            _fcm_send(m.user.fcm_token, title, body,
                      {"type": "club_event", "event_id": str(event.id),
                       "club_id": str(club_id)})
    except Exception as e:
        logger.error(f"push_club_event_notification: {e}")


# ── Game challenge request (matches current sender/receiver model) ─

@shared_task(name="push_game_request_notification", ignore_result=True)
def push_game_request_notification(request_id):
    from apps.arcade.models import GameRequest
    try:
        gr    = GameRequest.objects.select_related("sender", "receiver").get(id=request_id)
        game  = gr.game_name or gr.game_slug
        title = "Game request! \U0001F3AE"
        body  = f"{gr.sender.display_name} challenged you to {game}!"
        if gr.wager:
            body += f" ({gr.wager} \U0001FA99)"
        notif = _create(str(gr.receiver.id), str(gr.sender.id), "game_request",
                        title, body, "game_request", str(gr.id))
        if notif:
            _fcm_send(gr.receiver.fcm_token, title, body,
                      {"type": "game_request", "request_id": str(request_id)})
    except Exception as e:
        logger.error(f"push_game_request_notification: {e}")


# ── Event reminders (periodic) ────────────────────────────────

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
