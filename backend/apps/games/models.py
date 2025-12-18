from django.db import models
from django.utils import timezone
from apps.users.models import User


class Game(models.Model):
    """Model for arcade games."""
    
    GAME_CHOICES = [
        ('campus_craft', 'Campus Craft'),
        ('ninja_tag', 'Ninja Tag'),
        ('sushi_rush', 'Sushi Rush Kitchen'),
        ('battle_bots', 'Battle Bots'),
        ('spirit_racers', 'Spirit Racers'),
        ('pool_royale', 'Pool Royale'),
    ]
    
    game_id = models.CharField(max_length=50, choices=GAME_CHOICES, unique=True)
    name = models.CharField(max_length=100)
    description = models.TextField()
    thumbnail = models.ImageField(upload_to='games/', blank=True, null=True)
    
    # Settings
    is_active = models.BooleanField(default=True)
    is_multiplayer = models.BooleanField(default=False)
    max_players = models.IntegerField(default=1)
    
    # Timestamps
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['name']
        verbose_name = 'Game'
        verbose_name_plural = 'Games'
    
    def __str__(self):
        return self.name


class GameScore(models.Model):
    """Model for game scores and leaderboard."""
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='game_scores')
    game = models.ForeignKey(Game, on_delete=models.CASCADE, related_name='scores')
    
    # Score details
    score = models.IntegerField()
    level = models.IntegerField(default=1)
    duration = models.IntegerField(help_text="Duration in seconds")
    
    # Additional data
    achievements = models.JSONField(default=list, blank=True)
    replay_url = models.URLField(blank=True, null=True)
    
    # Timestamps
    played_at = models.DateTimeField(default=timezone.now)
    
    class Meta:
        ordering = ['-score', '-played_at']
        verbose_name = 'Game Score'
        verbose_name_plural = 'Game Scores'
        indexes = [
            models.Index(fields=['game', '-score']),
            models.Index(fields=['user', '-played_at']),
        ]
    
    def __str__(self):
        return f"{self.user.name} - {self.game.name}: {self.score}"


class Achievement(models.Model):
    """Model for game achievements."""
    
    game = models.ForeignKey(Game, on_delete=models.CASCADE, related_name='achievements')
    name = models.CharField(max_length=100)
    description = models.TextField()
    icon = models.ImageField(upload_to='achievements/', blank=True, null=True)
    
    # Requirements
    requirement = models.JSONField(help_text="JSON describing how to unlock")
    points = models.IntegerField(default=10)
    
    # Stats
    unlocked_by = models.ManyToManyField(User, through='UserAchievement', related_name='achievements')
    
    created_at = models.DateTimeField(default=timezone.now)
    
    class Meta:
        ordering = ['game', 'name']
        verbose_name = 'Achievement'
        verbose_name_plural = 'Achievements'
    
    def __str__(self):
        return f"{self.game.name} - {self.name}"


class UserAchievement(models.Model):
    """Model for tracking user achievements."""
    
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    achievement = models.ForeignKey(Achievement, on_delete=models.CASCADE)
    unlocked_at = models.DateTimeField(default=timezone.now)
    
    class Meta:
        unique_together = ('user', 'achievement')
        ordering = ['-unlocked_at']
    
    def __str__(self):
        return f"{self.user.name} - {self.achievement.name}"
