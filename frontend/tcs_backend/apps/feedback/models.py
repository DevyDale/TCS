# apps/feedback/models.py
import uuid
from django.db import models
from django.conf import settings


class Suggestion(models.Model):
    CATEGORY_CHOICES = [
        ('feature',   '💡 Feature Request'),
        ('bug',       '🐛 Bug Report'),
        ('content',   '📚 Content & Curriculum'),
        ('ui',        '🎨 Design & UI'),
        ('general',   '💬 General Feedback'),
        ('complaint', '⚠️ Complaint'),
    ]

    STATUS_CHOICES = [
        ('new',         'New'),
        ('under_review','Under Review'),
        ('planned',     'Planned'),
        ('done',        'Done'),
        ('wont_do',     "Won't Do"),
    ]

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name='suggestions')
    category   = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='general')
    title      = models.CharField(max_length=120)
    message    = models.TextField()
    status     = models.CharField(max_length=20, choices=STATUS_CHOICES, default='new')
    admin_note = models.TextField(blank=True)   # admin can leave a note
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'suggestions'
        ordering = ['-created_at']

    def __str__(self):
        return f'[{self.category}] {self.title} — {self.user}'