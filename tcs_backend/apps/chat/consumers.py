import json
import logging
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.utils import timezone

logger = logging.getLogger("apps.chat")


class ChatConsumer(AsyncWebsocketConsumer):

    # ── Connect / Disconnect ──────────────────────────────────

    async def connect(self):
        self.user = self.scope.get("user")
        if not self.user or not self.user.is_authenticated:
            await self.close(code=4001)
            return

        self.room_id    = self.scope["url_route"]["kwargs"]["room_id"]
        self.room_group = f"chat_{self.room_id}"

        if not await self._is_member():
            await self.close(code=4003)
            return

        await self.channel_layer.group_add(self.room_group, self.channel_name)
        await self.accept()
        await self._set_online(True)

        await self.channel_layer.group_send(self.room_group, {
            "type":      "user.presence",
            "user_id":   str(self.user.id),
            "is_online": True,
        })

    async def disconnect(self, code):
        if not hasattr(self, "room_group"):
            return
        await self.channel_layer.group_discard(self.room_group, self.channel_name)
        await self._set_online(False)
        await self.channel_layer.group_send(self.room_group, {
            "type":      "user.presence",
            "user_id":   str(self.user.id),
            "is_online": False,
            "last_seen": timezone.now().isoformat(),
        })

    # ── Receive from client ───────────────────────────────────

    async def receive(self, text_data=None, bytes_data=None):
        try:
            data = json.loads(text_data or "{}")
        except json.JSONDecodeError:
            return await self._err("Invalid JSON")

        action = data.get("action", "")
        handler = {
            "message":        self._handle_message,
            "typing":         self._handle_typing,
            "read":           self._handle_read,
            "reaction":       self._handle_reaction,
            "delete_message": self._handle_delete,
            "edit_message":   self._handle_edit,
            "fetch_history":  self._handle_history,
        }.get(action)

        if handler:
            await handler(data)
        else:
            await self._err(f"Unknown action: {action}")

    # ── Handlers ─────────────────────────────────────────────

    async def _handle_message(self, data):
        msg_type   = data.get("message_type", "text")
        text       = data.get("text", "").strip()
        media_url  = data.get("media_url", "")
        reply_to   = data.get("reply_to")
        sticker_id = data.get("sticker_id")
        mentions   = data.get("mentions", [])

        if msg_type == "text" and not text:
            return await self._err("Text cannot be empty.")

        msg = await self._save_message(msg_type, text, media_url, reply_to, sticker_id)
        if not msg:
            return await self._err("Could not save message.")

        if mentions:
            await self._set_mentions(msg["id"], mentions)

        await self.channel_layer.group_send(self.room_group,
                                            {"type": "chat.message", "payload": msg})

        # Push notification (fire-and-forget)
        try:
            from apps.notifications.tasks import push_chat_notification
            push_chat_notification.delay(msg["id"], str(self.room_id))
        except Exception:
            pass

    async def _handle_typing(self, data):
        await self.channel_layer.group_send(self.room_group, {
            "type":         "user.typing",
            "user_id":      str(self.user.id),
            "display_name": self.user.display_name,
            "is_typing":    bool(data.get("is_typing", False)),
        })

    async def _handle_read(self, data):
        mid = data.get("message_id")
        if not mid:
            return
        await self._mark_read(mid)
        await self.channel_layer.group_send(self.room_group, {
            "type":       "read.receipt",
            "message_id": mid,
            "user_id":    str(self.user.id),
            "read_at":    timezone.now().isoformat(),
        })

    async def _handle_reaction(self, data):
        mid   = data.get("message_id")
        emoji = data.get("emoji", "")
        if not mid or not emoji:
            return
        result = await self._toggle_reaction(mid, emoji)
        await self.channel_layer.group_send(self.room_group, {
            "type":              "message.reaction",
            "message_id":        mid,
            "user_id":           str(self.user.id),
            "emoji":             emoji,
            "action":            result["action"],
            "reactions_summary": result["summary"],
        })

    async def _handle_delete(self, data):
        mid = data.get("message_id")
        if not mid:
            return
        ok = await self._delete_message(mid)
        if ok:
            await self.channel_layer.group_send(self.room_group, {
                "type":       "message.deleted",
                "message_id": mid,
                "deleted_by": str(self.user.id),
            })

    async def _handle_edit(self, data):
        mid      = data.get("message_id")
        new_text = data.get("text", "").strip()
        if not mid or not new_text:
            return
        ok = await self._edit_message(mid, new_text)
        if ok:
            await self.channel_layer.group_send(self.room_group, {
                "type":       "message.edited",
                "message_id": mid,
                "text":       new_text,
                "edited_at":  timezone.now().isoformat(),
            })

    async def _handle_history(self, data):
        before = data.get("before_message_id")
        limit  = min(int(data.get("limit", 30)), 50)
        msgs   = await self._get_history(before, limit)
        await self.send(text_data=json.dumps({
            "event":    "history",
            "messages": msgs,
            "has_more": len(msgs) == limit,
        }))

    # ── Channel layer event dispatchers ──────────────────────

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({"event": "message", **event["payload"]}))

    async def user_typing(self, event):
        await self.send(text_data=json.dumps({
            "event":        "typing",
            "user_id":      event["user_id"],
            "display_name": event["display_name"],
            "is_typing":    event["is_typing"],
        }))

    async def user_presence(self, event):
        await self.send(text_data=json.dumps({
            "event":     "presence",
            "user_id":   event["user_id"],
            "is_online": event["is_online"],
            "last_seen": event.get("last_seen"),
        }))

    async def read_receipt(self, event):
        await self.send(text_data=json.dumps({
            "event":      "read_receipt",
            "message_id": event["message_id"],
            "user_id":    event["user_id"],
            "read_at":    event["read_at"],
        }))

    async def message_reaction(self, event):
        await self.send(text_data=json.dumps({
            "event":             "reaction",
            "message_id":        event["message_id"],
            "user_id":           event["user_id"],
            "emoji":             event["emoji"],
            "action":            event["action"],
            "reactions_summary": event["reactions_summary"],
        }))

    async def message_deleted(self, event):
        await self.send(text_data=json.dumps({
            "event":      "message_deleted",
            "message_id": event["message_id"],
            "deleted_by": event["deleted_by"],
        }))

    async def message_edited(self, event):
        await self.send(text_data=json.dumps({
            "event":      "message_edited",
            "message_id": event["message_id"],
            "text":       event["text"],
            "edited_at":  event["edited_at"],
        }))

    # ── DB helpers ────────────────────────────────────────────

    @database_sync_to_async
    def _is_member(self):
        from .models import RoomMember
        return RoomMember.objects.filter(
            room_id=self.room_id, user=self.user, is_banned=False
        ).exists()

    @database_sync_to_async
    def _set_online(self, online):
        self.user.mark_online() if online else self.user.mark_offline()

    @database_sync_to_async
    def _save_message(self, msg_type, text, media_url, reply_to_id, sticker_id):
        from .models import Message, Room
        try:
            room = Room.objects.get(id=self.room_id)
            msg  = Message.objects.create(
                room=room, sender=self.user,
                message_type=msg_type, text=text,
                media_url=media_url or "",
                reply_to_id=reply_to_id,
                sticker_id=sticker_id,
            )
            Room.objects.filter(id=self.room_id).update(
                last_message_text=msg.display_text,
                last_message_at=timezone.now(),
                last_message_sender=self.user,
            )
            return {
                "id":           str(msg.id),
                "room_id":      str(msg.room_id),
                "sender_id":    self.user.user_id,
                "sender_name":  self.user.display_name,
                "message_type": msg_type,
                "text":         text,
                "media_url":    media_url or None,
                "reply_to":     str(reply_to_id) if reply_to_id else None,
                "reactions":    [],
                "is_edited":    False,
                "is_deleted":   False,
                "created_at":   msg.created_at.isoformat(),
            }
        except Exception as e:
            logger.error(f"save_message error: {e}")
            return None

    @database_sync_to_async
    def _set_mentions(self, message_id, mention_ids):
        from .models import Message
        from django.contrib.auth import get_user_model
        U = get_user_model()
        try:
            msg   = Message.objects.get(id=message_id)
            users = U.objects.filter(id__in=mention_ids)
            msg.mentions.set(users)
        except Exception:
            pass

    @database_sync_to_async
    def _mark_read(self, message_id):
        from .models import ReadReceipt, Message
        try:
            msg = Message.objects.get(id=message_id)
            ReadReceipt.objects.get_or_create(message=msg, user=self.user)
        except Exception:
            pass

    @database_sync_to_async
    def _toggle_reaction(self, message_id, emoji):
        from .models import MessageReaction, Message
        from django.db.models import Count
        try:
            msg      = Message.objects.get(id=message_id)
            existing = MessageReaction.objects.filter(message=msg, user=self.user)
            if existing.exists():
                existing.delete()
                action = "removed"
            else:
                MessageReaction.objects.create(message=msg, user=self.user, emoji=emoji)
                action = "added"
            summary = dict(
                msg.reactions.values("emoji")
                .annotate(c=Count("id"))
                .values_list("emoji", "c")
            )
            return {"action": action, "summary": summary}
        except Exception:
            return {"action": "error", "summary": {}}

    @database_sync_to_async
    def _delete_message(self, message_id):
        from .models import Message
        try:
            msg = Message.objects.get(id=message_id, sender=self.user)
            msg.is_deleted   = True
            msg.deleted_at   = timezone.now()
            msg.text         = ""
            msg.message_type = Message.MsgType.DELETED
            msg.save(update_fields=["is_deleted", "deleted_at", "text", "message_type"])
            return True
        except Message.DoesNotExist:
            return False

    @database_sync_to_async
    def _edit_message(self, message_id, new_text):
        from .models import Message
        try:
            msg = Message.objects.get(
                id=message_id, sender=self.user,
                message_type=Message.MsgType.TEXT, is_deleted=False
            )
            msg.text      = new_text
            msg.is_edited = True
            msg.edited_at = timezone.now()
            msg.save(update_fields=["text", "is_edited", "edited_at"])
            return True
        except Message.DoesNotExist:
            return False

    @database_sync_to_async
    def _get_history(self, before_id, limit):
        from .models import Message
        qs = Message.objects.filter(room_id=self.room_id).select_related("sender", "sticker")
        if before_id:
            try:
                pivot = Message.objects.get(id=before_id)
                qs    = qs.filter(created_at__lt=pivot.created_at)
            except Message.DoesNotExist:
                pass
        msgs = list(qs.order_by("-created_at")[:limit])
        msgs.reverse()
        return [
            {
                "id":           str(m.id),
                "sender_id":    m.sender.user_id if m.sender else None,
                "sender_name":  m.sender.display_name if m.sender else "Unknown",
                "message_type": m.message_type,
                "text":         m.text,
                "media_url":    m.media_url or None,
                "file_name":    m.file_name or None,
                "is_edited":    m.is_edited,
                "is_deleted":   m.is_deleted,
                "created_at":   m.created_at.isoformat(),
            }
            for m in msgs
        ]

    async def _err(self, detail):
        await self.send(text_data=json.dumps({"event": "error", "detail": detail}))
