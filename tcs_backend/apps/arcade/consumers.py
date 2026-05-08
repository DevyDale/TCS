# apps/arcade/consumers.py
#
# /ws/arcade/match/<session_id>/?token=<jwt>
#
# Multiplexed protocol — every message has an "action" field:
#
#   ── From players ────────────────────────────────────────────
#     {action: "state",  payload: {...}}        # broadcast game state to all
#     {action: "result", score: 1234}           # report final score (player only)
#     {action: "forfeit"}                       # quit (player only)
#
#   ── From anyone (player or spectator) ───────────────────────
#     {action: "chat",   text: "good shot!"}    # text message
#     {action: "cheer",  emoji: "🔥"}           # one-tap cheer
#
#   ── Server → client ─────────────────────────────────────────
#     {type: "state",      from: <user_id>, payload: {...}}
#     {type: "chat",       from: <user_id>, text: ..., user_tag: ...}
#     {type: "cheer",      from: <user_id>, emoji: ..., user_tag: ...}
#     {type: "presence",   user_id: ..., joined: true/false, count: <int>}
#     {type: "result",     user_id: ..., score: ...}
#     {type: "settled",    winner_id: ..., pot: ..., placements: [...]}
#     {type: "error",      message: "..."}

import json
import time
import logging
from uuid import UUID

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.utils import timezone
from django.contrib.auth import get_user_model

from .models import (
    GameSession, SessionPlayer, MatchMessage,
)
from . import services
from .serializers import GameSessionSerializer, MatchMessageSerializer

User   = get_user_model()
logger = logging.getLogger("apps.arcade")


# Rate-limit settings
CHEER_COOLDOWN_S = 1.0      # 1 cheer/sec/user
CHAT_COOLDOWN_S  = 2.0      # 1 message/2sec/user
MAX_CHAT_LEN     = 120


class MatchConsumer(AsyncWebsocketConsumer):
    """Live match WebSocket. Players and spectators share the same group."""

    # ── Connect / Disconnect ──────────────────────────────────
    async def connect(self):
        self.user = self.scope.get("user")
        if not self.user or not self.user.is_authenticated:
            await self.close(code=4001)
            return

        try:
            self.session_id = UUID(self.scope["url_route"]["kwargs"]["session_id"])
        except (ValueError, KeyError):
            await self.close(code=4002)
            return
        self.group = f"match_{self.session_id}"

        sess = await self._fetch_session()
        if sess is None:
            await self.close(code=4004)
            return

        self.is_player    = await self._is_player(sess.id)
        self.last_chat    = 0.0
        self.last_cheer   = 0.0

        await self.channel_layer.group_add(self.group, self.channel_name)
        await self.accept()

        # Increment spectator count if a watcher (not a player)
        if not self.is_player:
            await self._inc_spectator(+1)

        # Tell everyone someone joined
        count = await self._spectator_count()
        await self.channel_layer.group_send(self.group, {
            "type":     "presence",
            "user_id":  str(self.user.pk),
            "user_tag": self.user.gamer_tag or "",
            "joined":   True,
            "is_player": self.is_player,
            "count":    count,
        })

        # Send the new connection a snapshot of the session
        snapshot = await self._serialize_session(sess.id)
        if snapshot:
            await self.send(text_data=json.dumps({
                "type":    "snapshot",
                "session": snapshot,
            }))

    async def disconnect(self, code):
        if not hasattr(self, "group"):
            return
        await self.channel_layer.group_discard(self.group, self.channel_name)
        if not getattr(self, "is_player", False):
            await self._inc_spectator(-1)
        count = await self._spectator_count()
        await self.channel_layer.group_send(self.group, {
            "type":     "presence",
            "user_id":  str(self.user.pk),
            "user_tag": self.user.gamer_tag or "",
            "joined":   False,
            "is_player": getattr(self, "is_player", False),
            "count":    count,
        })

    # ── Receive ───────────────────────────────────────────────
    async def receive(self, text_data=None, bytes_data=None):
        try:
            data = json.loads(text_data or "{}")
        except json.JSONDecodeError:
            return await self._err("Invalid JSON")

        action = data.get("action", "")
        if action == "state":
            if not self.is_player:
                return await self._err("Only players can broadcast state.")
            await self.channel_layer.group_send(self.group, {
                "type":    "state.broadcast",
                "from":    str(self.user.pk),
                "payload": data.get("payload"),
            })

        elif action == "result":
            if not self.is_player:
                return await self._err("Only players can submit results.")
            score = max(0, int(data.get("score", 0)))
            settled = await self._submit_result(score)
            await self.channel_layer.group_send(self.group, {
                "type":    "result.broadcast",
                "from":    str(self.user.pk),
                "score":   score,
            })
            if settled:
                snap = await self._serialize_session(self.session_id)
                payload = settled.copy()
                payload["session"] = snap
                await self.channel_layer.group_send(self.group, {
                    "type": "settled.broadcast",
                    **payload,
                })

        elif action == "forfeit":
            if not self.is_player:
                return await self._err("Only players can forfeit.")
            settled = await self._forfeit()
            await self.channel_layer.group_send(self.group, {
                "type":    "forfeit.broadcast",
                "from":    str(self.user.pk),
            })
            if settled:
                snap = await self._serialize_session(self.session_id)
                payload = settled.copy()
                payload["session"] = snap
                await self.channel_layer.group_send(self.group, {
                    "type": "settled.broadcast",
                    **payload,
                })

        elif action == "chat":
            now = time.time()
            if now - self.last_chat < CHAT_COOLDOWN_S:
                return  # silently rate-limit
            self.last_chat = now
            text = (data.get("text") or "").strip()[:MAX_CHAT_LEN]
            if not text:
                return
            await self._save_message(kind="message", text=text, emoji="")
            await self.channel_layer.group_send(self.group, {
                "type":     "chat.broadcast",
                "from":     str(self.user.pk),
                "user_tag": self.user.gamer_tag or "",
                "user_name": self.user.display_name,
                "text":     text,
            })

        elif action == "cheer":
            now = time.time()
            if now - self.last_cheer < CHEER_COOLDOWN_S:
                return
            self.last_cheer = now
            emoji = (data.get("emoji") or "🔥")[:8]
            await self._save_message(kind="cheer", text="", emoji=emoji)
            await self.channel_layer.group_send(self.group, {
                "type":     "cheer.broadcast",
                "from":     str(self.user.pk),
                "user_tag": self.user.gamer_tag or "",
                "emoji":    emoji,
            })
        else:
            await self._err(f"Unknown action: {action}")

    # ── Group event handlers (named via the "type" field) ─────
    async def state_broadcast(self, e):
        await self.send(text_data=json.dumps({
            "type":    "state",  "from": e["from"], "payload": e.get("payload"),
        }))
    async def chat_broadcast(self, e):
        await self.send(text_data=json.dumps({
            "type":      "chat",
            "from":      e["from"], "user_tag": e["user_tag"],
            "user_name": e.get("user_name", ""), "text": e["text"],
        }))
    async def cheer_broadcast(self, e):
        await self.send(text_data=json.dumps({
            "type":     "cheer",
            "from":     e["from"], "user_tag": e["user_tag"],
            "emoji":    e["emoji"],
        }))
    async def result_broadcast(self, e):
        await self.send(text_data=json.dumps({
            "type": "result", "from": e["from"], "score": e["score"],
        }))
    async def forfeit_broadcast(self, e):
        await self.send(text_data=json.dumps({
            "type": "forfeit", "from": e["from"],
        }))
    async def settled_broadcast(self, e):
        await self.send(text_data=json.dumps({
            "type":   "settled",
            "winner": e.get("winner"),  "pot": e.get("pot"),
            "draw":   e.get("draw"),     "settled": e.get("settled"),
            "session": e.get("session"),
        }))
    async def presence(self, e):
        await self.send(text_data=json.dumps({
            "type":      "presence",
            "user_id":   e["user_id"],
            "user_tag":  e.get("user_tag", ""),
            "joined":    e["joined"],
            "is_player": e.get("is_player", False),
            "count":     e["count"],
        }))

    # ── Helpers ───────────────────────────────────────────────
    async def _err(self, msg):
        await self.send(text_data=json.dumps({"type": "error", "message": msg}))

    @database_sync_to_async
    def _fetch_session(self):
        try:
            return (GameSession.objects.select_related("game")
                    .get(pk=self.session_id))
        except GameSession.DoesNotExist:
            return None

    @database_sync_to_async
    def _is_player(self, session_id):
        return SessionPlayer.objects.filter(
            session_id=session_id, user=self.user).exists()

    @database_sync_to_async
    def _inc_spectator(self, delta):
        sess = GameSession.objects.filter(pk=self.session_id).first()
        if sess:
            new_val = max(0, sess.spectator_count + delta)
            GameSession.objects.filter(pk=self.session_id).update(
                spectator_count=new_val)

    @database_sync_to_async
    def _spectator_count(self):
        try:
            return GameSession.objects.values_list(
                "spectator_count", flat=True).get(pk=self.session_id)
        except GameSession.DoesNotExist:
            return 0

    @database_sync_to_async
    def _save_message(self, kind, text, emoji):
        return MatchMessage.objects.create(
            session_id=self.session_id, user=self.user,
            kind=kind, text=text, emoji=emoji,
        )

    @database_sync_to_async
    def _serialize_session(self, sid):
        try:
            sess = (GameSession.objects.select_related("game", "winner")
                    .prefetch_related("participants__user").get(pk=sid))
        except GameSession.DoesNotExist:
            return None
        return GameSessionSerializer(sess).data

    @database_sync_to_async
    def _submit_result(self, score):
        """Returns a payout dict if settled, else None."""
        sess = GameSession.objects.select_related("invite").get(pk=self.session_id)
        sp = sess.participants.filter(user=self.user).first()
        if sp is None or sess.status == "completed":
            return None
        sp.score       = score
        sp.finished_at = timezone.now()
        sp.save(update_fields=["score", "finished_at"])
        pending = sess.participants.filter(
            finished_at__isnull=True, forfeited=False).exists()
        if pending:
            return None
        scores    = {p.user_id: p.score      for p in sess.participants.all()}
        forfeited = [p.user_id for p in sess.participants.all() if p.forfeited]
        try:
            return services.settle_match(sess, scores, forfeited_by=forfeited)
        except services.MatchAlreadySettled:
            return None

    @database_sync_to_async
    def _forfeit(self):
        sess = GameSession.objects.get(pk=self.session_id)
        sp = sess.participants.filter(user=self.user).first()
        if sp is None or sess.status == "completed":
            return None
        sp.forfeited   = True
        sp.score       = 0
        sp.finished_at = timezone.now()
        sp.save(update_fields=["forfeited", "score", "finished_at"])
        pending = sess.participants.filter(
            finished_at__isnull=True, forfeited=False).count()
        if pending > 1:
            return None
        scores    = {p.user_id: p.score      for p in sess.participants.all()}
        forfeited = [p.user_id for p in sess.participants.all() if p.forfeited]
        try:
            return services.settle_match(sess, scores, forfeited_by=forfeited)
        except services.MatchAlreadySettled:
            return None