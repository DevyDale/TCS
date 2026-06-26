# apps/feedback/models.py
import uuid
from django.db import models
from django.conf import settings


class Category(models.Model):
    """
    Backend-driven feedback category. Replaces the old hardcoded
    CATEGORY_CHOICES tuple so admins can add, remove, or reorder
    categories from the Django admin without a code change.

    Each category carries its own emoji and gradient pair so the
    frontend can render the picker tiles entirely from data — no
    hardcoded styling per key.

    `is_active=False` keeps a category in the DB (so legacy suggestions
    that point at it don't lose their label) but hides it from the
    picker API. That's the migration story for retiring "General".
    """
    id            = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    key           = models.SlugField(
                        max_length=40, unique=True,
                        help_text="Stable identifier sent over the wire (e.g. 'bug').")
    label         = models.CharField(max_length=80)
    emoji         = models.CharField(max_length=8, blank=True)
    gradient_from = models.CharField(
                        max_length=9, default="#6DD5FA",
                        help_text="Hex starting colour for the picker tile gradient.")
    gradient_to   = models.CharField(
                        max_length=9, default="#8E54E9",
                        help_text="Hex ending colour for the picker tile gradient.")
    sort_order    = models.PositiveSmallIntegerField(default=100)
    is_active     = models.BooleanField(
                        default=True,
                        help_text="Inactive categories stay in the DB but don't appear "
                                  "in the picker API.")
    created_at    = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "feedback_categories"
        ordering = ["sort_order", "label"]

    def __str__(self):
        return f"{self.emoji} {self.label}".strip()


class Suggestion(models.Model):
    STATUS_CHOICES = [
        ('new',          'New'),
        ('under_review', 'Under Review'),
        ('planned',      'Planned'),
        ('done',         'Done'),
        ('wont_do',      "Won't Do"),
    ]

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name='suggestions')
    # Nullable + SET_NULL so an admin deleting a Category doesn't
    # cascade-wipe historical suggestions. The suggestion just becomes
    # uncategorised (the UI handles that gracefully).
    category   = models.ForeignKey(Category, on_delete=models.SET_NULL,
                                   null=True, blank=True,
                                   related_name='suggestions')
    title      = models.CharField(max_length=120)
    message    = models.TextField()
    status     = models.CharField(max_length=20, choices=STATUS_CHOICES, default='new')
    admin_note = models.TextField(blank=True)
    # Staff triage fields.
    priority    = models.IntegerField(default=0)           # 0–100, AI/staff-set
    assigned_to = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                    on_delete=models.SET_NULL,
                                    related_name='assigned_suggestions')
    theme       = models.CharField(max_length=80, blank=True, default='')  # AI cluster label
    is_flagged  = models.BooleanField(default=False)       # routed to Protect
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'suggestions'
        ordering = ['-created_at']

    def __str__(self):
        cat = str(self.category) if self.category_id else 'uncategorised'
        return f'[{cat}] {self.title} — {self.user}'
    
