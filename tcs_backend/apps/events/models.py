import uuid
from django.db import models
from django.conf import settings


class Event(models.Model):
    class Category(models.TextChoices):
        ACADEMIC = "academic", "Academic"
        SPORTS   = "sports",   "Sports"
        CLUB     = "club",     "Club"
        SOCIAL   = "social",   "Social"
        ARCADE   = "arcade",   "Arcade"
        OTHER    = "other",    "Other"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title       = models.CharField(max_length=200)
    description = models.TextField()
    category    = models.CharField(max_length=15, choices=Category.choices)
    organizer   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="organized_events")
    group       = models.ForeignKey("groups.Group", null=True, blank=True,
                                    on_delete=models.SET_NULL)
    image       = models.ImageField(upload_to="events/%Y/%m/", null=True, blank=True)
    location    = models.CharField(max_length=200)
    is_online   = models.BooleanField(default=False)
    meeting_url = models.URLField(blank=True)
    start_time  = models.DateTimeField(db_index=True)
    end_time    = models.DateTimeField()
    max_attendees   = models.PositiveIntegerField(null=True, blank=True)
    attendees_count = models.PositiveIntegerField(default=0)
    is_featured = models.BooleanField(default=False)
    is_active   = models.BooleanField(default=True)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "events"
        ordering = ["start_time"]

    def __str__(self):
        return self.title

    @property
    def is_full(self):
        return bool(self.max_attendees and self.attendees_count >= self.max_attendees)


class EventRSVP(models.Model):
    event      = models.ForeignKey(Event, on_delete=models.CASCADE, related_name="rsvps")
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "event_rsvps"
        unique_together = [("event", "user")]
