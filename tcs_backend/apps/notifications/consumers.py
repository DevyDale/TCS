import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async


class NotificationConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        user = self.scope.get("user")
        if not user or not user.is_authenticated:
            await self.close(code=4001)
            return

        self.user       = user
        self.group_name = f"notif_{str(user.id).replace('-', '_')}"

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

        unread = await self._unread_count()
        await self.send(text_data=json.dumps({
            "event":        "connected",
            "unread_count": unread,
        }))

    async def disconnect(self, code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        try:
            data = json.loads(text_data or "{}")
        except json.JSONDecodeError:
            return

        action = data.get("action")
        if action == "mark_read":
            await self._mark_read(data.get("id"))
        elif action == "mark_all_read":
            await self._mark_all_read()

    # ── Channel layer dispatch ────────────────────────────────

    async def send_notification(self, event):
        await self.send(text_data=json.dumps({
            "event":       "notification",
            "id":          event.get("id"),
            "notif_type":  event.get("notif_type"),
            "title":       event.get("title"),
            "body":        event.get("body"),
            "actor_name":  event.get("actor_name"),
            "target_type": event.get("target_type"),
            "target_id":   event.get("target_id"),
            "created_at":  event.get("created_at"),
        }))

    # ── DB helpers ────────────────────────────────────────────

    @database_sync_to_async
    def _unread_count(self):
        from .models import Notification
        return Notification.objects.filter(recipient=self.user, is_read=False).count()

    @database_sync_to_async
    def _mark_read(self, notif_id):
        if notif_id:
            from .models import Notification
            Notification.objects.filter(id=notif_id, recipient=self.user).update(is_read=True)

    @database_sync_to_async
    def _mark_all_read(self):
        from .models import Notification
        Notification.objects.filter(recipient=self.user, is_read=False).update(is_read=True)
