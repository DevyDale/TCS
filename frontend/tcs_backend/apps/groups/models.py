import uuid
from django.db import models
from django.conf import settings
from django.utils import timezone


class Group(models.Model):
    class Category(models.TextChoices):
        STUDY    = "study",    "Study"
        HOBBY    = "hobby",    "Hobby"
        CLUB     = "club",     "Club"
        FACULTY  = "faculty",  "Faculty"
        PROJECT  = "project",  "Project"
        ARCADE   = "arcade",   "Arcade"
        ACADEMIC = "academic", "Academic"

    class Theme(models.TextChoices):
        MATHEMATICS = "mathematics", "Mathematics"
        SCIENCE     = "science",     "Science"
        ARTS        = "arts",        "Arts"
        TECHNOLOGY  = "technology",  "Technology"
        SPORTS      = "sports",      "Sports"
        MUSIC       = "music",       "Music"
        BUSINESS    = "business",    "Business"
        LANGUAGE    = "language",    "Language"
        GAMING      = "gaming",      "Gaming"
        GENERAL     = "general",     "General"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name        = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    purpose     = models.TextField(blank=True)
    category    = models.CharField(max_length=15, choices=Category.choices, default=Category.STUDY)
    theme       = models.CharField(max_length=20, choices=Theme.choices, default=Theme.GENERAL)
    subject     = models.CharField(max_length=100, blank=True)
    avatar      = models.ImageField(upload_to="group_avatars/%Y/", null=True, blank=True)
    # Auto-icon emoji based on theme (stored as string e.g. "📚")
    theme_icon  = models.CharField(max_length=10, blank=True)

    is_academic = models.BooleanField(default=True)
    created_by  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                    null=True, related_name="created_groups")
    members     = models.ManyToManyField(settings.AUTH_USER_MODEL, through="GroupMember",
                                         related_name="study_groups")
    admins      = models.ManyToManyField(settings.AUTH_USER_MODEL,
                                         related_name="admin_groups", blank=True)

    is_public          = models.BooleanField(default=True)
    requires_approval  = models.BooleanField(default=False)
    is_active          = models.BooleanField(default=True)
    members_count      = models.PositiveIntegerField(default=0)
    active_now         = models.PositiveIntegerField(default=0)

    # Duration (auto-deactivate after this many days; null = no expiry)
    duration_days = models.PositiveIntegerField(null=True, blank=True)
    expires_at    = models.DateTimeField(null=True, blank=True)
    dissolved_at  = models.DateTimeField(null=True, blank=True)
    dissolve_reason = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "groups"
        ordering = ["-members_count"]

    def __str__(self):
        return self.name

    THEME_ICONS = {
        "mathematics": "📐", "science": "🔬", "arts": "🎨",
        "technology": "💻", "sports": "⚽", "music": "🎵",
        "business": "💼", "language": "🌍", "gaming": "🎮", "general": "👥",
    }

    def save(self, *args, **kwargs):
        # Auto-assign theme icon
        if not self.theme_icon:
            self.theme_icon = self.THEME_ICONS.get(self.theme, "👥")
        # Set expiry based on duration_days
        if self.duration_days and not self.expires_at:
            self.expires_at = timezone.now() + timezone.timedelta(days=self.duration_days)
        super().save(*args, **kwargs)


class GroupMember(models.Model):
    class Status(models.TextChoices):
        ACTIVE  = "active",  "Active"
        PENDING = "pending", "Pending"
        BANNED  = "banned",  "Banned"

    group     = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="memberships")
    user      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    status    = models.CharField(max_length=10, choices=Status.choices, default=Status.ACTIVE)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "group_members"
        unique_together = [("group", "user")]


class GroupMaterial(models.Model):
    """Files shared in a group."""
    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    group      = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="materials")
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    title      = models.CharField(max_length=200)
    file       = models.FileField(upload_to="group_materials/%Y/%m/")
    file_name  = models.CharField(max_length=200, blank=True)
    file_type  = models.CharField(max_length=50, blank=True)
    file_size  = models.PositiveIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "group_materials"
        ordering = ["-created_at"]