import uuid
from django.db import models
from django.conf import settings


class Notification(models.Model):
    class Type(models.TextChoices):
        LIKE                = "like",                "Like"
        COMMENT             = "comment",             "Comment"
        FOLLOW              = "follow",              "Follow"
        MENTION             = "mention",             "Mention"
        CHAT_MESSAGE        = "chat_message",        "Chat Message"
        CHAT_REQUEST        = "chat_request",        "Chat Request"
        GAME_REQUEST        = "game_request",        "Game Request"
        EVENT_REMINDER      = "event_reminder",      "Event Reminder"
        HIGHLIGHT           = "highlight",           "New Highlight"
        STUDY_BUDDY_REQUEST = "study_buddy_request", "Study Buddy Request"
        STUDY_GROUP_INVITE  = "study_group_invite",  "Study Group Invite"
        ACHIEVEMENT         = "achievement",         "Achievement"
        SYSTEM              = "system",              "System"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipient   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                    related_name="notifications")
    actor       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                    null=True, blank=True, related_name="+")
    notif_type  = models.CharField(max_length=30, choices=Type.choices)
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