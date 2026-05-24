# apps/arcade/models.py
#
# Full overhaul:
#   • TokenLedger        — audit trail for every wallet write
#   • TokenTransfer      — peer-to-peer wallet transfers
#   • GameInvite         — parent invite (1 sender → 1-4 recipients)
#   • GameRequest        — per-recipient row (kept for backward compat;
#                          gains an `invite` FK)
#   • GameSession        — gains pot, ended_at, spectator_count, extra_players
#   • SessionPlayer      — through-model for royale games
#   • MatchMessage       — cheers / comments during live matches
#
# Existing fields on Game, GameScore, PlayerStats, GameRequest, GameSession
# are preserved so old data and old code paths keep working.
import uuid
import datetime

from django.db import models
from django.conf import settings
from django.utils import timezone


# ─────────────────────────────────────────────────────────────
# Game
# ─────────────────────────────────────────────────────────────
class Game(models.Model):
    class Category(models.TextChoices):
        PUZZLE      = "puzzle",      "Puzzle"
        ACTION      = "action",      "Action"
        TRIVIA      = "trivia",      "Trivia"
        MULTIPLAYER = "multiplayer", "Multiplayer"
        COOP        = "coop",        "Co-op"
        RACING      = "racing",      "Racing"
        STRATEGY    = "strategy",    "Strategy"
        SPORTS      = "sports",      "Sports"

    class InviteMode(models.TextChoices):
        SOLO_ONLY   = "solo_only",   "Solo only (no challenges)"
        FIRST_COME  = "first_come",  "First-come duel (1v1, multi-invite OK)"
        ROYALE      = "royale",      "Battle royale (everyone who accepts joins)"

    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name         = models.CharField(max_length=80)
    slug         = models.SlugField(unique=True)
    description  = models.TextField()
    category     = models.CharField(max_length=15, choices=Category.choices)
    thumbnail    = models.ImageField(upload_to="game_thumbs/", null=True, blank=True)
    min_players  = models.PositiveSmallIntegerField(default=1)
    max_players  = models.PositiveSmallIntegerField(default=8)
    xp_reward    = models.PositiveSmallIntegerField(default=50)
    token_reward = models.PositiveSmallIntegerField(default=10)
    is_active    = models.BooleanField(default=True)
    is_featured  = models.BooleanField(default=False)
    play_count   = models.PositiveIntegerField(default=0)

    # NEW: how this game handles multiplayer invites
    invite_mode  = models.CharField(max_length=15, choices=InviteMode.choices,
                                    default=InviteMode.FIRST_COME)
    # NEW: live spectator support
    streamable   = models.BooleanField(default=True)

    class Meta:
        db_table = "games"

    def __str__(self):
        return self.name

    @property
    def supports_multi_invite(self):
        return self.invite_mode == self.InviteMode.ROYALE


# ─────────────────────────────────────────────────────────────
# GameScore (per-play score row, used for solo + leaderboards)
# ─────────────────────────────────────────────────────────────
class GameScore(models.Model):
    game      = models.ForeignKey(Game, on_delete=models.CASCADE, related_name="scores")
    user      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    score     = models.IntegerField(default=0)
    played_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "game_scores"
        ordering = ["-score"]
        indexes  = [models.Index(fields=["game", "-score"])]


# ─────────────────────────────────────────────────────────────
# PlayerStats — kept for backward compat (User.tokens is the
# authoritative wallet; PlayerStats just holds aggregate counters).
# ─────────────────────────────────────────────────────────────
class PlayerStats(models.Model):
    user   = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                  related_name="player_stats")
    tokens = models.IntegerField(default=100)

    class Meta:
        db_table = "player_stats"

    def __str__(self):
        return f"{self.user} — {self.tokens} tokens"


# ─────────────────────────────────────────────────────────────
# TokenLedger — every wallet write goes through this.
# `delta` is signed; the ledger is the source of truth for audit.
# ─────────────────────────────────────────────────────────────
class TokenLedger(models.Model):
    class Reason(models.TextChoices):
        SOLO_WIN       = "solo_win",       "Solo Game Reward"
        MATCH_WIN      = "match_win",      "Match Win Payout"
        WAGER_ESCROW   = "wager_escrow",   "Wager Escrowed"
        WAGER_REFUND   = "wager_refund",   "Wager Refunded"
        TRANSFER_IN    = "transfer_in",    "Transfer Received"
        TRANSFER_OUT   = "transfer_out",   "Transfer Sent"
        DAILY_STIPEND  = "daily_stipend",  "Daily Login Stipend"
        SIGNUP_BONUS   = "signup_bonus",   "Signup Bonus"
        ADMIN_GRANT    = "admin_grant",    "Admin Grant"
        ADMIN_DEDUCT   = "admin_deduct",   "Admin Deduct"

    id              = models.BigAutoField(primary_key=True)
    user            = models.ForeignKey(settings.AUTH_USER_MODEL,
                                        on_delete=models.CASCADE,
                                        related_name="token_ledger")
    delta           = models.IntegerField()                       # signed
    balance_after   = models.IntegerField()
    reason          = models.CharField(max_length=20, choices=Reason.choices)
    reference_type  = models.CharField(max_length=40, blank=True) # e.g. 'GameSession'
    reference_id    = models.CharField(max_length=64, blank=True) # uuid as string
    note            = models.CharField(max_length=140, blank=True)
    created_at      = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "token_ledger"
        ordering = ["-created_at"]
        indexes  = [
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["reference_type", "reference_id"]),
        ]

    def __str__(self):
        sign = "+" if self.delta >= 0 else ""
        return f"{self.user} {sign}{self.delta} ({self.reason})"


# ─────────────────────────────────────────────────────────────
# TokenTransfer — peer-to-peer transfer record
# ─────────────────────────────────────────────────────────────
class TokenTransfer(models.Model):
    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    sender      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="sent_transfers")
    recipient   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="received_transfers")
    amount      = models.PositiveIntegerField()
    note        = models.CharField(max_length=140, blank=True)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "token_transfers"
        ordering = ["-created_at"]
        indexes  = [
            models.Index(fields=["sender", "-created_at"]),
            models.Index(fields=["recipient", "-created_at"]),
        ]


# ─────────────────────────────────────────────────────────────
# GameInvite — parent invite. One sender → 1..4 recipients.
# When created the sender's wager is immediately escrowed.
# ─────────────────────────────────────────────────────────────
class GameInvite(models.Model):
    STATUS = [
        ("pending",   "Pending"),     # waiting for at least one acceptance
        ("started",   "Started"),     # session created, game in progress
        ("completed", "Completed"),
        ("expired",   "Expired"),
        ("cancelled", "Cancelled"),
    ]

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    sender      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="sent_invites")
    game        = models.ForeignKey(Game, on_delete=models.CASCADE,
                                    related_name="invites")
    wager       = models.PositiveIntegerField(default=0)
    invite_mode = models.CharField(max_length=15)   # snapshot of game.invite_mode
    status      = models.CharField(max_length=20, choices=STATUS, default="pending")
    created_at  = models.DateTimeField(auto_now_add=True)
    expires_at  = models.DateTimeField()

    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = timezone.now() + datetime.timedelta(minutes=30)
        super().save(*args, **kwargs)

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at and self.status == "pending"

    class Meta:
        db_table = "game_invites"
        ordering = ["-created_at"]
        indexes  = [
            models.Index(fields=["sender", "status"]),
            models.Index(fields=["status", "expires_at"]),
        ]

    def __str__(self):
        return f"{self.sender} → {self.game.slug} ({self.status})"


# ─────────────────────────────────────────────────────────────
# GameRequest — per-recipient row. Kept for backward compat;
# now linked to a GameInvite parent.
# ─────────────────────────────────────────────────────────────
class GameRequest(models.Model):
    STATUS = [
        ("pending",   "Pending"),
        ("accepted",  "Accepted"),
        ("declined",  "Declined"),
        ("expired",   "Expired"),
        ("auto_declined", "Auto-Declined"),  # other recipient locked it
    ]

    id        = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # NEW: link to parent invite (nullable so old rows keep working)
    invite    = models.ForeignKey(GameInvite, on_delete=models.CASCADE,
                                  related_name="requests", null=True, blank=True)

    # Legacy fields (kept; populated for backward compat)
    sender    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                  related_name="sent_challenges")
    receiver  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                  related_name="received_challenges")
    game_slug = models.CharField(max_length=60)
    game_name = models.CharField(max_length=100)
    wager     = models.IntegerField(default=0)
    status    = models.CharField(max_length=20, choices=STATUS, default="pending")
    paid      = models.BooleanField(default=False)            # NEW
    responded_at = models.DateTimeField(null=True, blank=True) # NEW

    created_at= models.DateTimeField(auto_now_add=True)
    expires_at= models.DateTimeField(null=True, blank=True)

    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = timezone.now() + datetime.timedelta(minutes=30)
        super().save(*args, **kwargs)

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at if self.expires_at else False

    class Meta:
        db_table = "game_requests"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.sender} → {self.receiver} | {self.game_slug} ({self.status})"


# ─────────────────────────────────────────────────────────────
# GameSession — the actual match. A session has 2..N players.
# Pot is the sum of all escrowed wagers; winner takes all.
# ─────────────────────────────────────────────────────────────
class GameSession(models.Model):
    STATUS = [
        ("waiting",   "Waiting for players"),
        ("active",    "Active"),
        ("completed", "Completed"),
        ("abandoned", "Abandoned"),
    ]

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # NEW preferred linkage
    invite      = models.OneToOneField(GameInvite, on_delete=models.CASCADE,
                                       related_name="session", null=True, blank=True)
    game        = models.ForeignKey(Game, on_delete=models.PROTECT,
                                    related_name="sessions", null=True, blank=True)

    # Legacy linkage — kept so existing 1v1 code paths still work
    request     = models.OneToOneField(GameRequest, on_delete=models.CASCADE,
                                       related_name="session", null=True, blank=True)
    player1     = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="p1_sessions", null=True, blank=True)
    player2     = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="p2_sessions", null=True, blank=True)

    game_slug   = models.CharField(max_length=60, blank=True)
    wager       = models.IntegerField(default=0)
    pot         = models.PositiveIntegerField(default=0)             # NEW
    p1_score    = models.IntegerField(default=0)
    p2_score    = models.IntegerField(default=0)
    status      = models.CharField(max_length=20, choices=STATUS, default="waiting")

    # 1v1 control flags (legacy)
    p1_paused   = models.BooleanField(default=False)
    p2_paused   = models.BooleanField(default=False)
    p1_quit     = models.BooleanField(default=False)
    p2_quit     = models.BooleanField(default=False)
    paused_at   = models.DateTimeField(null=True, blank=True)

    winner      = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                    on_delete=models.SET_NULL,
                                    related_name="won_sessions")

    spectator_count = models.PositiveIntegerField(default=0)         # NEW
    started_at  = models.DateTimeField(null=True, blank=True)        # NEW
    ended_at    = models.DateTimeField(null=True, blank=True)        # NEW

    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "game_sessions"
        ordering = ["-created_at"]
        indexes  = [
            models.Index(fields=["status", "-created_at"]),
            models.Index(fields=["game_slug", "status"]),
        ]

    def __str__(self):
        return f"Session {self.id} — {self.game_slug} ({self.status})"


# ─────────────────────────────────────────────────────────────
# SessionPlayer — through-model for >2 player royale matches.
# (For 1v1 we still use player1/player2 on GameSession.)
# ─────────────────────────────────────────────────────────────
class SessionPlayer(models.Model):
    id          = models.BigAutoField(primary_key=True)
    session     = models.ForeignKey(GameSession, on_delete=models.CASCADE,
                                    related_name="participants")
    user        = models.ForeignKey(settings.AUTH_USER_MODEL,
                                    on_delete=models.CASCADE,
                                    related_name="session_seats")
    wager_paid  = models.PositiveIntegerField(default=0)
    score       = models.IntegerField(default=0)
    placement   = models.PositiveSmallIntegerField(default=0)  # 1=winner
    forfeited   = models.BooleanField(default=False)
    joined_at   = models.DateTimeField(auto_now_add=True)
    finished_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "game_session_players"
        unique_together = [("session", "user")]


# ─────────────────────────────────────────────────────────────
# MatchMessage — cheers + comments from spectators (or players)
# during a live match. Persisted briefly for the post-match view.
# ─────────────────────────────────────────────────────────────
class MatchMessage(models.Model):
    class Kind(models.TextChoices):
        CHEER   = "cheer",   "Cheer"     # emoji-only reaction
        MESSAGE = "message", "Message"   # text comment

    id         = models.BigAutoField(primary_key=True)
    session    = models.ForeignKey(GameSession, on_delete=models.CASCADE,
                                   related_name="match_messages")
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    kind       = models.CharField(max_length=10, choices=Kind.choices,
                                  default=Kind.MESSAGE)
    text       = models.CharField(max_length=120, blank=True)
    emoji      = models.CharField(max_length=8, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "match_messages"
        ordering = ["-created_at"]
        indexes  = [models.Index(fields=["session", "-created_at"])]

# >>> tcs-notify:game-request
from django.db.models.signals import post_save as _nz_post_save
from django.dispatch import receiver as _nz_receiver

@_nz_receiver(_nz_post_save, sender=GameRequest)
def _nz_notify_game_request(sender, instance, created, **kwargs):
    if not created:
        return
    try:
        from apps.notifications.tasks import push_game_request_notification
        push_game_request_notification.delay(str(instance.id))
    except Exception:
        pass
# <<< tcs-notify:game-request
