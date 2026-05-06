# apps/arcade/models.py  — complete, clean, no duplicates
import uuid
import datetime

from django.db import models
from django.conf import settings
from django.utils import timezone


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

    class Meta:
        db_table = "games"

    def __str__(self):
        return self.name


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
class PlayerStats(models.Model):
    """Per-user token wallet + aggregate stats."""
    user   = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                  related_name="player_stats")
    tokens = models.IntegerField(default=100)   # starting wallet balance

    class Meta:
        db_table = "player_stats"

    def __str__(self):
        return f"{self.user} — {self.tokens} tokens"


# ─────────────────────────────────────────────────────────────
# ONE GameRequest class (sender/receiver + wager + expiry)
# The old from_user/to_user version is removed.
# ─────────────────────────────────────────────────────────────
class GameRequest(models.Model):
    STATUS = [
        ("pending",   "Pending"),
        ("accepted",  "Accepted"),
        ("declined",  "Declined"),
        ("expired",   "Expired"),
        ("completed", "Completed"),
    ]

    id        = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    sender    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                  related_name="sent_challenges")
    receiver  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                  related_name="received_challenges")
    game_slug = models.CharField(max_length=60)
    game_name = models.CharField(max_length=100)
    wager     = models.IntegerField(default=0)
    status    = models.CharField(max_length=20, choices=STATUS, default="pending")
    created_at= models.DateTimeField(auto_now_add=True)
    expires_at= models.DateTimeField(null=True, blank=True)

    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = timezone.now() + datetime.timedelta(minutes=30)
        super().save(*args, **kwargs)

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at

    class Meta:
        db_table = "game_requests"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.sender} → {self.receiver} | {self.game_slug} ({self.status})"


# ─────────────────────────────────────────────────────────────
class GameSession(models.Model):
    STATUS = [
        ("active",    "Active"),
        ("completed", "Completed"),
        ("abandoned", "Abandoned"),
    ]

    id        = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request   = models.OneToOneField(GameRequest, on_delete=models.CASCADE,
                                     related_name="session")
    player1   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                  related_name="p1_sessions")
    player2   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                  related_name="p2_sessions")
    game_slug = models.CharField(max_length=60)
    wager     = models.IntegerField(default=0)
    p1_score  = models.IntegerField(default=0)
    p2_score  = models.IntegerField(default=0)
    winner    = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                  on_delete=models.SET_NULL, related_name="won_sessions")
    status    = models.CharField(max_length=20, choices=STATUS, default="active")
    p1_paused = models.BooleanField(default=False)
    p2_paused = models.BooleanField(default=False)
    p1_quit   = models.BooleanField(default=False)
    p2_quit   = models.BooleanField(default=False)
    paused_at = models.DateTimeField(null=True, blank=True)
    created_at= models.DateTimeField(auto_now_add=True)
    updated_at= models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "game_sessions"

    def __str__(self):
        return f"{self.player1} vs {self.player2} | {self.game_slug}"