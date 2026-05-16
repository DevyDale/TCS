# apps/clubs/models.py
import uuid
from django.db import models
from django.conf import settings


class Club(models.Model):
    """
    A campus club — distinct from study Groups.
    Membership is gated by the (optional) approval flow and role
    hierarchy is President > Executive > Member.
    """
    class Category(models.TextChoices):
        # Match the frontend category list exactly (clubs_list_screen.dart,
        # search_clubs_screen.dart, create_club_page.dart).
        ACADEMIC       = "academic",       "Academic"
        SPORTS         = "sports",         "Sports"
        ARTS           = "arts",           "Arts"
        CULTURAL       = "cultural",       "Cultural"
        TECHNOLOGY     = "technology",     "Technology"
        SOCIAL_SERVICE = "social_service", "Social Service"
        BUSINESS       = "business",       "Business"
        GAMING         = "gaming",         "Gaming"
        OTHER          = "other",          "Other"

    CATEGORY_ICONS = {
        "academic":       "📚",
        "sports":         "⚽",
        "arts":           "🎨",
        "cultural":       "🌍",
        "technology":     "💻",
        "social_service": "🤝",
        "business":       "💼",
        "gaming":         "🎮",
        "other":          "🎯",
    }

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name        = models.CharField(max_length=120)

    # Short hook line shown on cards & header. Frontend caps at 160.
    tagline     = models.CharField(max_length=200, blank=True)
    description = models.TextField(blank=True)

    # Long-form admin-edited content shown on the About tab.
    mission     = models.TextField(blank=True)
    rules       = models.TextField(blank=True)
    purpose     = models.TextField(blank=True)

    # Contact info (About tab "Contact" card).
    contact_email = models.EmailField(blank=True)
    contact_phone = models.CharField(max_length=40, blank=True)

    category    = models.CharField(max_length=20, choices=Category.choices,
                                   default=Category.OTHER)

    # Imagery — logo is the small icon, cover is the wide hero image.
    logo        = models.ImageField(upload_to="club_logos/%Y/",  null=True, blank=True)
    cover       = models.ImageField(upload_to="club_covers/%Y/", null=True, blank=True)
    chat_room_id = models.UUIDField(null=True, blank=True)
    theme_icon  = models.CharField(max_length=10, blank=True)

    # Settings
    is_public          = models.BooleanField(default=True)
    requires_approval  = models.BooleanField(default=False)
    is_verified        = models.BooleanField(default=False)
    is_active          = models.BooleanField(default=True)

    # Stats
    members_count = models.PositiveIntegerField(default=0)

    # Lifecycle
    created_by      = models.ForeignKey(settings.AUTH_USER_MODEL,
                                        on_delete=models.SET_NULL, null=True,
                                        related_name="created_clubs")
    members         = models.ManyToManyField(settings.AUTH_USER_MODEL,
                                             through="ClubMember",
                                             related_name="clubs")

    created_at      = models.DateTimeField(auto_now_add=True)
    updated_at      = models.DateTimeField(auto_now=True)
    dissolved_at    = models.DateTimeField(null=True, blank=True)
    dissolve_reason = models.TextField(blank=True)

    class Meta:
        db_table = "clubs"
        ordering = ["-members_count", "-created_at"]

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if not self.theme_icon:
            self.theme_icon = self.CATEGORY_ICONS.get(self.category, "🎯")
        super().save(*args, **kwargs)


class ClubMember(models.Model):
    """
    Membership row joining a User to a Club.
    `role` powers the admin hierarchy.
    """
    class Status(models.TextChoices):
        ACTIVE  = "active",  "Active"
        PENDING = "pending", "Pending"
        BANNED  = "banned",  "Banned"

    class Role(models.TextChoices):
        MEMBER    = "member",    "Member"
        EXECUTIVE = "executive", "Executive"
        PRESIDENT = "president", "President"

    club      = models.ForeignKey(Club, on_delete=models.CASCADE,
                                  related_name="memberships")
    user      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    status    = models.CharField(max_length=10, choices=Status.choices,
                                 default=Status.ACTIVE)
    role      = models.CharField(max_length=12, choices=Role.choices,
                                 default=Role.MEMBER)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "club_members"
        unique_together = [("club", "user")]
        ordering = ["joined_at"]

    def __str__(self):
        return f"{self.user} @ {self.club} ({self.role})"


class ClubInvite(models.Model):
    """An admin-initiated invitation for a user to join a club.

    Lives independently of ClubMember so we can track the lifecycle
    (pending → accepted/declined) and surface it via Notifications.
    On accept, a ClubMember row is created with status='active'.
    """
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('declined', 'Declined'),
    ]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    club = models.ForeignKey(
        'Club', on_delete=models.CASCADE, related_name='invites')
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='club_invites_sent')
    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='club_invites_received')
    status = models.CharField(
        max_length=12, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['club', 'recipient'],
                condition=models.Q(status='pending'),
                name='unique_pending_club_invite',
            ),
        ]

    def __str__(self):
        return f"{self.sender} → {self.recipient} ({self.club}, {self.status})"
