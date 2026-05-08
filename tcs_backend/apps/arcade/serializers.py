# apps/arcade/serializers.py
from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.db.models  import Max

from .models import (
    Game, GameScore, GameInvite, GameRequest, GameSession,
    SessionPlayer, TokenLedger, TokenTransfer, MatchMessage,
)

User = get_user_model()


# ─────────────────────────────────────────────────────────────
class GameSerializer(serializers.ModelSerializer):
    my_best_score = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()

    class Meta:
        model  = Game
        fields = ["id", "name", "slug", "description", "category",
                  "thumbnail_url", "min_players", "max_players",
                  "xp_reward", "token_reward", "is_featured",
                  "play_count", "my_best_score",
                  "invite_mode", "streamable"]

    def get_thumbnail_url(self, obj):
        req = self.context.get("request")
        if obj.thumbnail:
            return req.build_absolute_uri(obj.thumbnail.url) if req else obj.thumbnail.url
        return None

    def get_my_best_score(self, obj):
        req = self.context.get("request")
        if req and req.user.is_authenticated:
            r = GameScore.objects.filter(game=obj, user=req.user).aggregate(Max("score"))
            return r["score__max"]
        return None


# ─────────────────────────────────────────────────────────────
class _MiniUserSerializer(serializers.Serializer):
    user_id      = serializers.CharField()
    display_name = serializers.CharField()
    gamer_tag    = serializers.CharField()
    avatar_url   = serializers.SerializerMethodField()
    level        = serializers.IntegerField()

    def get_avatar_url(self, obj):
        req = self.context.get("request")
        if not getattr(obj, "avatar", None):
            return None
        try:
            url = obj.avatar.url
        except Exception:
            return None
        return req.build_absolute_uri(url) if req else url

    def to_representation(self, obj):
        return {
            "user_id":      obj.user_id,
            "display_name": obj.display_name,
            "gamer_tag":    obj.gamer_tag or "",
            "avatar_url":   self.get_avatar_url(obj),
            "level":        obj.level,
        }


# ─────────────────────────────────────────────────────────────
class GameInviteSerializer(serializers.ModelSerializer):
    sender         = serializers.SerializerMethodField()
    game_name      = serializers.CharField(source="game.name",  read_only=True)
    game_slug      = serializers.CharField(source="game.slug",  read_only=True)
    recipients     = serializers.SerializerMethodField()
    accepted_count = serializers.SerializerMethodField()
    pending_count  = serializers.SerializerMethodField()

    class Meta:
        model  = GameInvite
        fields = ["id", "sender", "game_name", "game_slug", "wager",
                  "invite_mode", "status", "created_at", "expires_at",
                  "recipients", "accepted_count", "pending_count"]

    def _ctx(self): return self.context
    def get_sender(self, obj):
        return _MiniUserSerializer(obj.sender, context=self._ctx()).data
    def get_recipients(self, obj):
        return [
            {
                "request_id":   str(gr.id),
                "user":         _MiniUserSerializer(gr.receiver, context=self._ctx()).data,
                "status":       gr.status,
                "responded_at": gr.responded_at.isoformat() if gr.responded_at else None,
            }
            for gr in obj.requests.select_related("receiver").all()
        ]
    def get_accepted_count(self, obj):
        return obj.requests.filter(status="accepted").count()
    def get_pending_count(self, obj):
        return obj.requests.filter(status="pending").count()


# ─────────────────────────────────────────────────────────────
class GameRequestSerializer(serializers.ModelSerializer):
    """Used for incoming requests (the receiver's view)."""
    sender_name   = serializers.CharField(source="sender.display_name",     read_only=True)
    sender_tag    = serializers.CharField(source="sender.gamer_tag",        read_only=True)
    sender_avatar = serializers.SerializerMethodField()
    sender_level  = serializers.IntegerField(source="sender.level",         read_only=True)
    invite_id     = serializers.CharField(source="invite.id",               read_only=True)

    class Meta:
        model  = GameRequest
        fields = ["id", "invite_id",
                  "sender_name", "sender_tag", "sender_avatar", "sender_level",
                  "game_name", "game_slug", "wager",
                  "status", "created_at", "expires_at"]

    def get_sender_avatar(self, obj):
        req = self.context.get("request")
        if obj.sender.avatar:
            try:
                url = obj.sender.avatar.url
                return req.build_absolute_uri(url) if req else url
            except Exception:
                return None
        return None


# ─────────────────────────────────────────────────────────────
class SessionPlayerSerializer(serializers.ModelSerializer):
    user = _MiniUserSerializer(read_only=True)

    class Meta:
        model  = SessionPlayer
        fields = ["user", "wager_paid", "score", "placement",
                  "forfeited", "finished_at"]


class GameSessionSerializer(serializers.ModelSerializer):
    game_name    = serializers.SerializerMethodField()
    game_slug    = serializers.CharField()
    participants = SessionPlayerSerializer(many=True, read_only=True)
    winner       = serializers.SerializerMethodField()

    class Meta:
        model  = GameSession
        fields = ["id", "game_name", "game_slug", "wager", "pot",
                  "status", "winner", "spectator_count",
                  "participants", "created_at", "started_at", "ended_at"]

    def get_game_name(self, obj):
        return obj.game.name if obj.game_id else obj.game_slug
    def get_winner(self, obj):
        if not obj.winner_id:
            return None
        return _MiniUserSerializer(obj.winner, context=self.context).data


# ─────────────────────────────────────────────────────────────
class TokenLedgerSerializer(serializers.ModelSerializer):
    class Meta:
        model  = TokenLedger
        fields = ["id", "delta", "balance_after", "reason",
                  "reference_type", "reference_id", "note", "created_at"]


class TokenTransferSerializer(serializers.ModelSerializer):
    sender    = _MiniUserSerializer(read_only=True)
    recipient = _MiniUserSerializer(read_only=True)
    direction = serializers.SerializerMethodField()

    class Meta:
        model  = TokenTransfer
        fields = ["id", "sender", "recipient", "amount", "note",
                  "direction", "created_at"]

    def get_direction(self, obj):
        req = self.context.get("request")
        if not (req and req.user.is_authenticated):
            return None
        return "out" if obj.sender_id == req.user.pk else "in"


# ─────────────────────────────────────────────────────────────
class MatchMessageSerializer(serializers.ModelSerializer):
    user_tag    = serializers.CharField(source="user.gamer_tag",    read_only=True)
    user_name   = serializers.CharField(source="user.display_name", read_only=True)

    class Meta:
        model  = MatchMessage
        fields = ["id", "kind", "text", "emoji",
                  "user_tag", "user_name", "created_at"]