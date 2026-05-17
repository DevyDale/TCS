# apps/events/models.py
import uuid
from django.db import models
from django.conf import settings
from cloudinary.models import CloudinaryField


class Event(models.Model):
    """
    Phase 2 spec:
      - Each event must have a poster image (10.2). The image field is now
        a Cloudinary asset, matching the rest of the app's media handling.
      - Existing local file uploads are preserved; the migration converts
        the column type but does not migrate the actual files. If you have
        production events with local images, run `manage.py reupload_event_images`
        (separate utility) to push them to Cloudinary.
    """

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

    # Club association.
    club        = models.ForeignKey(
        "clubs.Club", null=True, blank=True,
        on_delete=models.CASCADE,
        related_name="club_events",
    )

    # Phase 6 — Club ownership.
    # Mirrors Post.club. Used by the in-club Feed tab and the
    # arcade's Club Activity Hub to surface a club's events.
    club        = models.ForeignKey("clubs.Club", null=True, blank=True,
                                    on_delete=models.SET_NULL,
                                    related_name="events")
    # ── Poster (Cloudinary) ──────────────────────────────────────
    # Was ImageField('events/%Y/%m/'), now CloudinaryField for parity with
    # avatars/covers/post media. django_cleanup deletes the asset when this
    # field is overwritten or the event is deleted.
    image = CloudinaryField(
        "image",
        folder="tcs_studenthub/events",
        blank=True,
        null=True,
        overwrite=True,
        resource_type="image",
    )

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
    """
    Phase 2 spec 9.4: RSVP is now a 3-state field rather than a binary
    "exists or doesn't exist" toggle. States:

      - going        — user confirms attendance
      - interested   — user wants to keep an eye on it
      - not_going    — user explicitly declined (kept on record so they
                       don't get reminders, distinct from "no response")

    `attendees_count` on the parent Event tracks GOING only. Interested and
    not_going users do not count towards capacity.
    """

    class Status(models.TextChoices):
        GOING      = "going",      "Going"
        INTERESTED = "interested", "Interested"
        NOT_GOING  = "not_going",  "Not going"

    event      = models.ForeignKey(Event, on_delete=models.CASCADE, related_name="rsvps")
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    status     = models.CharField(max_length=12, choices=Status.choices,
                                  default=Status.GOING)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "event_rsvps"
        unique_together = [("event", "user")]
        indexes = [
            models.Index(fields=["event", "status"]),
        ]

    def __str__(self):
        return f"{self.user} → {self.event} ({self.status})"
