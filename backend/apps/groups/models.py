from django.db import models
from django.utils import timezone
from apps.users.models import User


class Group(models.Model):
    """Model for study groups and clubs."""
    
    GROUP_TYPE_CHOICES = [
        ('study', 'Study Group'),
        ('club', 'Club'),
        ('sport', 'Sport'),
        ('event', 'Event'),
    ]
    
    name = models.CharField(max_length=200)
    description = models.TextField()
    group_type = models.CharField(max_length=20, choices=GROUP_TYPE_CHOICES)
    
    # Management
    creator = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_groups')
    moderators = models.ManyToManyField(User, related_name='moderated_groups', blank=True)
    members = models.ManyToManyField(User, through='GroupMembership', related_name='joined_groups')
    
    # Media
    cover_image = models.ImageField(upload_to='groups/', blank=True, null=True)
    
    # Settings
    is_private = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    max_members = models.IntegerField(default=100)
    
    # Timestamps
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Group'
        verbose_name_plural = 'Groups'
    
    def __str__(self):
        return f"{self.name} ({self.get_group_type_display()})"


class GroupMembership(models.Model):
    """Model for group membership."""
    
    ROLE_CHOICES = [
        ('member', 'Member'),
        ('moderator', 'Moderator'),
        ('admin', 'Admin'),
    ]
    
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    group = models.ForeignKey(Group, on_delete=models.CASCADE)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='member')
    joined_at = models.DateTimeField(default=timezone.now)
    
    class Meta:
        unique_together = ('user', 'group')
        ordering = ['-joined_at']
    
    def __str__(self):
        return f"{self.user.name} in {self.group.name}"
