import uuid
from django.db import models
from django.conf import settings


class Room(models.Model):
    class RoomType(models.TextChoices):
        DIRECT      = "direct",       "Direct Message"
        GROUP       = "group",        "Group Chat"
        CHANNEL     = "channel",      "Channel"
        STUDY_BUDDY = "study_buddy",  "Study Buddy"

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    room_type   = models.CharField(max_length=15, choices=RoomType.choices,
                                   default=RoomType.DIRECT)
    name        = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    avatar      = models.ImageField(upload_to="room_avatars/%Y/", null=True, blank=True)
    created_by  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                    null=True, related_name="created_rooms")
    admins      = models.ManyToManyField(settings.AUTH_USER_MODEL,
                                         related_name="admin_rooms", blank=True)
    members     = models.ManyToManyField(settings.AUTH_USER_MODEL, through="RoomMember",
                                         related_name="chat_rooms")
    direct_key  = models.CharField(max_length=200, unique=True, null=True, blank=True,
                                   db_index=True)
    is_active   = models.BooleanField(default=True)

    # ── Chat Bubble + AI fields (Phase 1) ────────────────────
    is_public   = models.BooleanField(default=False, db_index=True)
    about       = models.TextField(blank=True)
    ai_enabled  = models.BooleanField(default=False)

    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    last_message_text   = models.TextField(blank=True)
    last_message_at     = models.DateTimeField(null=True, blank=True)
    last_message_sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                            null=True, blank=True, related_name="+")

    class Meta:
        db_table = "chat_rooms"
        ordering = ["-last_message_at", "-created_at"]

    def __str__(self):
        return self.name or f"Room {self.id}"

    @classmethod
    def get_or_create_direct(cls, user_a, user_b):
        ids = sorted([str(user_a.id), str(user_b.id)])
        key = f"dm__{ids[0]}__{ids[1]}"
        room, created = cls.objects.get_or_create(
            direct_key=key,
            defaults={"room_type": cls.RoomType.DIRECT},
        )
        if created:
            RoomMember.objects.bulk_create([
                RoomMember(room=room, user=user_a),
                RoomMember(room=room, user=user_b),
            ])
        return room, created

    @classmethod
    def get_or_create_study_buddy(cls, user_a, user_b, subject=""):
        ids = sorted([str(user_a.id), str(user_b.id)])
        key = f"sb__{ids[0]}__{ids[1]}"
        room, created = cls.objects.get_or_create(
            direct_key=key,
            defaults={
                "room_type": cls.RoomType.STUDY_BUDDY,
                "name": f"Study Buddy ({subject})" if subject else "Study Buddy",
            },
        )
        if created:
            RoomMember.objects.bulk_create([
                RoomMember(room=room, user=user_a),
                RoomMember(room=room, user=user_b),
            ])
        return room, created


class RoomMember(models.Model):
    room      = models.ForeignKey(Room, on_delete=models.CASCADE, related_name="memberships")
    user      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    joined_at = models.DateTimeField(auto_now_add=True)
    is_muted  = models.BooleanField(default=False)
    is_banned = models.BooleanField(default=False)
    nickname  = models.CharField(max_length=50, blank=True)
    last_read_message = models.ForeignKey("Message", on_delete=models.SET_NULL,
                                          null=True, blank=True, related_name="+")

    class Meta:
        db_table = "chat_room_members"
        unique_together = [("room", "user")]


class Message(models.Model):
    class MsgType(models.TextChoices):
        TEXT     = "text",     "Text"
        IMAGE    = "image",    "Image"
        VIDEO    = "video",    "Video"
        AUDIO    = "audio",    "Audio / Voice Note"
        GIF      = "gif",      "GIF"
        STICKER  = "sticker",  "Sticker"
        FILE     = "file",     "File"
        DOCUMENT = "document", "Document"

    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    room         = models.ForeignKey(Room, on_delete=models.CASCADE, related_name="messages")
    # Phase 1: sender is now nullable + SET_NULL.
    #   • Lets AI-authored messages have null sender (Dale uses a system user
    #     so this isn't strictly required, but it's defensive)
    #   • Keeps message history intact when a user account is deleted
    sender       = models.ForeignKey(settings.AUTH_USER_MODEL,
                                     on_delete=models.SET_NULL,
                                     null=True, blank=True,
                                     related_name="sent_messages")
    message_type = models.CharField(max_length=10, choices=MsgType.choices, default=MsgType.TEXT)
    text         = models.TextField(blank=True)
    media        = models.FileField(upload_to="chat_media/%Y/%m/%d/", null=True, blank=True)
    media_url    = models.URLField(blank=True)
    thumbnail    = models.URLField(blank=True)
    file_name    = models.CharField(max_length=200, blank=True)
    file_size    = models.PositiveIntegerField(null=True, blank=True)
    duration     = models.PositiveIntegerField(null=True, blank=True)
    sticker_id   = models.PositiveIntegerField(null=True, blank=True)
    reply_to     = models.ForeignKey("self", null=True, blank=True, on_delete=models.SET_NULL,
                                     related_name="replies")
    is_deleted   = models.BooleanField(default=False)
    is_system    = models.BooleanField(default=False)
    is_ai        = models.BooleanField(default=False, db_index=True)   # Phase 1: marks Dale messages
    created_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "chat_messages"
        ordering = ["created_at"]
        indexes  = [models.Index(fields=["room", "created_at"])]

    @property
    def display_text(self):
        if self.is_deleted:
            return "This message was deleted."
        labels = {"image": "📷 Photo", "video": "🎥 Video", "audio": "🎵 Voice note",
                  "gif": "GIF", "sticker": "Sticker",
                  "document": f"📄 {self.file_name or 'Document'}",
                  "file": f"📎 {self.file_name or 'File'}"}
        return labels.get(self.message_type, self.text)


class MessageReaction(models.Model):
    message    = models.ForeignKey(Message, on_delete=models.CASCADE, related_name="reactions")
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    emoji      = models.CharField(max_length=10)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "chat_reactions"
        unique_together = [("message", "user")]


class ReadReceipt(models.Model):
    message = models.ForeignKey(Message, on_delete=models.CASCADE, related_name="read_receipts")
    user    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    read_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "chat_read_receipts"
        unique_together = [("message", "user")]


class StickerPack(models.Model):
    name       = models.CharField(max_length=80)
    thumbnail  = models.ImageField(upload_to="sticker_packs/")
    is_free    = models.BooleanField(default=True)
    token_cost = models.PositiveIntegerField(default=0)

    class Meta:
        db_table = "sticker_packs"

    def __str__(self):
        return self.name


class Sticker(models.Model):
    pack        = models.ForeignKey(StickerPack, on_delete=models.CASCADE, related_name="stickers")
    name        = models.CharField(max_length=80)
    image       = models.ImageField(upload_to="stickers/")
    is_animated = models.BooleanField(default=False)
    sort_order  = models.PositiveSmallIntegerField(default=0)

    class Meta:
        db_table = "stickers"
        ordering = ["sort_order"]


# ── Chat Request (for non-followers) ──────────────────────────

class ChatRequest(models.Model):
    class Status(models.TextChoices):
        PENDING  = "pending",  "Pending"
        ACCEPTED = "accepted", "Accepted"
        DECLINED = "declined", "Declined"

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    sender     = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name="sent_chat_requests")
    receiver   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name="received_chat_requests")
    message    = models.CharField(max_length=300, blank=True)
    status     = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    room       = models.ForeignKey(Room, null=True, blank=True, on_delete=models.SET_NULL)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "chat_requests"
        unique_together = [("sender", "receiver")]

    def __str__(self):
        return f"{self.sender} → {self.receiver} [{self.status}]"


# ── Saved Material ───────────────────────────────────────────

class SavedMaterial(models.Model):
    SOURCE_CHOICES = [
        ("chat",   "Chat"),
        ("group",  "Study Group"),
        ("manual", "Manual upload"),
    ]

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user        = models.ForeignKey(settings.AUTH_USER_MODEL,
                                    on_delete=models.CASCADE,
                                    related_name="saved_materials")
    message     = models.ForeignKey(Message, on_delete=models.CASCADE,
                                    related_name="saves",
                                    null=True, blank=True)

    title       = models.CharField(max_length=200, blank=True)
    file_url    = models.URLField(blank=True)
    file_name   = models.CharField(max_length=200, blank=True)
    file_type   = models.CharField(max_length=50, blank=True)

    # Library organisation + quiz seeding
    subject       = models.CharField(max_length=100, blank=True)
    source_type   = models.CharField(max_length=20, choices=SOURCE_CHOICES,
                                     default="chat", blank=True)
    source_group  = models.ForeignKey("groups.Group",
                                      on_delete=models.SET_NULL,
                                      null=True, blank=True,
                                      related_name="saved_materials")
    source_name   = models.CharField(max_length=200, blank=True)

    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "saved_materials"
        ordering = ["-created_at"]
        indexes  = [
            models.Index(fields=["user", "subject"],
                         name="savedmat_user_subj_idx"),
            models.Index(fields=["user", "source_group"],
                         name="savedmat_user_src_idx"),
        ]


# ── Chat Bubble Invitations (Phase 1) ────────────────────────

class RoomInvite(models.Model):
    """
    Pending / accepted / declined invitation to join a chat bubble (a Room
    with room_type=GROUP). Created by bubble_views.create_bubble (initial
    member_ids) and bubble_views.invite_to_bubble. Resolved by accept_invite
    and decline_invite.
    """
    class Status(models.TextChoices):
        PENDING  = "pending",  "Pending"
        ACCEPTED = "accepted", "Accepted"
        DECLINED = "declined", "Declined"

    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    room         = models.ForeignKey(Room, on_delete=models.CASCADE,
                                     related_name="invites")
    invitee      = models.ForeignKey(settings.AUTH_USER_MODEL,
                                     on_delete=models.CASCADE,
                                     related_name="received_room_invites")
    inviter      = models.ForeignKey(settings.AUTH_USER_MODEL,
                                     on_delete=models.SET_NULL,
                                     null=True, blank=True,
                                     related_name="sent_room_invites")
    status       = models.CharField(max_length=10, choices=Status.choices,
                                    default=Status.PENDING, db_index=True)
    message      = models.CharField(max_length=200, blank=True)
    created_at   = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "chat_room_invites"
        ordering = ["-created_at"]
        indexes  = [
            models.Index(fields=["invitee", "status"], name="invite_user_status_idx"),
        ]
        constraints = [
            # Only one pending invite per (room, invitee). Re-inviting after a
            # decline requires the previous invite's status to flip first.
            models.UniqueConstraint(
                fields=["room", "invitee"],
                condition=models.Q(status="pending"),
                name="unique_pending_invite_per_room_user",
            ),
        ]

    def __str__(self):
        return f"{self.inviter} → {self.invitee} [{self.room.name}] ({self.status})"