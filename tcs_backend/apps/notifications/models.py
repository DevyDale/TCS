import uuid
import cloudinary.models
from django.db import models
from django.conf import settings


class Notification(models.Model):
    class Type(models.TextChoices):
        LIKE             = "like",             "Like"
        COMMENT          = "comment",          "Comment"
        FOLLOW           = "follow",           "Follow"
        MENTION          = "mention",          "Mention"
        CHAT_MESSAGE     = "chat_message",     "Chat Message"
        CHAT_REQUEST     = "chat_request",     "Chat Request"
        REQUEST_ACCEPTED = "request_accepted", "Request Accepted"
        REQUEST_DECLINED = "request_declined", "Request Declined"
        GROUP_ADD        = "group_add",        "Added to Group"
        GROUP_MESSAGE    = "group_message",    "Group Message"
        GROUP_MATERIAL   = "group_material",   "Group Material"
        CLUB_EVENT       = "club_event",       "Club Event"
        GAME_REQUEST     = "game_request",     "Game Request"
        EVENT_REMINDER   = "event_reminder",   "Event Reminder"
        ACHIEVEMENT      = "achievement",      "Achievement"
        ANNOUNCEMENT     = "announcement",     "Announcement"
        SYSTEM           = "system",           "System"
        BIRTHDAY         = "birthday",         "Birthday"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipient   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="notifications")
    actor       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                    null=True, blank=True, related_name="+")
    notif_type  = models.CharField(max_length=20, choices=Type.choices)
    title       = models.CharField(max_length=200)
    body        = models.TextField()
    target_type = models.CharField(max_length=30, blank=True)
    target_id   = models.CharField(max_length=100, blank=True)
    is_read     = models.BooleanField(default=False, db_index=True)
    is_pushed   = models.BooleanField(default=False)
    created_at  = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "notifications"
        ordering = ["-created_at"]
        indexes  = [models.Index(fields=["recipient", "is_read"])]


class Announcement(models.Model):
    class Category(models.TextChoices):
        GENERAL   = "general",   "General"
        ACADEMIC  = "academic",  "Academic"
        EVENT     = "event",     "Event"
        JOB       = "job",       "Job / Opportunity"
        COMMUNITY = "community", "Community"
        URGENT    = "urgent",    "Urgent"

    class Audience(models.TextChoices):
        ALL        = "all",        "Everyone"
        STUDENTS   = "students",   "Students only"
        STAFF      = "staff",      "Staff only"
        YEAR_GROUP = "year_group", "Specific year group"

    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    author       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                     null=True, blank=True, related_name="announcements")
    title        = models.CharField(max_length=200)
    body         = models.TextField()
    category     = models.CharField(max_length=20, choices=Category.choices, default=Category.GENERAL)
    audience     = models.CharField(max_length=20, choices=Audience.choices, default=Audience.ALL)
    year_group   = models.CharField(max_length=20, blank=True, default="")
    image        = cloudinary.models.CloudinaryField("image", blank=True, null=True)
    image_url    = models.URLField(max_length=2000, blank=True, default="")  # external/AI banner
    accent       = models.CharField(max_length=9, blank=True, default="")  # optional hex card colour
    is_pinned    = models.BooleanField(default=False, db_index=True)
    is_published = models.BooleanField(default=True, db_index=True)
    publish_at   = models.DateTimeField(null=True, blank=True)   # reserved for scheduling
    expires_at   = models.DateTimeField(null=True, blank=True)
    view_count   = models.PositiveIntegerField(default=0)
    created_at   = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at   = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "announcements"
        ordering = ["-is_pinned", "-created_at"]
        indexes  = [models.Index(fields=["audience", "is_published"], name="announce_aud_pub_idx")]

    def __str__(self):
        return self.title
