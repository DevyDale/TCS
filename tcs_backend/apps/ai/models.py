# apps/ai/models.py
#
# AI app models:
#   - AiCompanion       persona definitions (seed + user-created)
#   - Conversation      a chat thread between user and companion
#   - ChatMessage       individual message in a Conversation
#   - ImageGeneration   record of a generated image (Pollinations URL)

import uuid
from django.db import models
from django.conf import settings


# ═════════════════════════════════════════════════════════════
# AI Companions (personas)
# ═════════════════════════════════════════════════════════════

class AiCompanion(models.Model):
    """An AI persona students can chat with (Einstein, Shakespeare, etc.)."""

    CATEGORY_SCIENCE     = "science"
    CATEGORY_LITERATURE  = "literature"
    CATEGORY_PHILOSOPHY  = "philosophy"
    CATEGORY_HISTORY     = "history"
    CATEGORY_TECH        = "tech"
    CATEGORY_STUDY       = "study"
    CATEGORY_GENERAL     = "general"
    CATEGORY_CHOICES = [
        (CATEGORY_SCIENCE,    "Science"),
        (CATEGORY_LITERATURE, "Literature"),
        (CATEGORY_PHILOSOPHY, "Philosophy"),
        (CATEGORY_HISTORY,    "History"),
        (CATEGORY_TECH,       "Tech"),
        (CATEGORY_STUDY,      "Study"),
        (CATEGORY_GENERAL,    "General"),
    ]

    id            = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name          = models.CharField(max_length=80)
    description   = models.CharField(max_length=200,
                                     help_text="Short tagline shown on cards")
    instructions  = models.TextField(
        help_text="Persona instructions: backstory, voice, behaviour rules")
    seed_chat     = models.TextField(blank=True,
        help_text="Optional example exchanges that anchor tone")

    # Visual
    avatar_emoji   = models.CharField(max_length=8,  default="🤖")
    gradient_start = models.CharField(max_length=9,  default="#6A11CB",
                                      help_text="Hex like #RRGGBB")
    gradient_end   = models.CharField(max_length=9,  default="#2575FC")

    category   = models.CharField(max_length=20, choices=CATEGORY_CHOICES,
                                  default=CATEGORY_GENERAL)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL,
                                   on_delete=models.SET_NULL,
                                   null=True, blank=True,
                                   related_name="created_companions")
    is_public  = models.BooleanField(default=True)
    is_seed    = models.BooleanField(default=False,
        help_text="True for built-in personas (cannot be deleted via API)")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-is_seed", "name"]
        indexes  = [models.Index(fields=["category", "is_public"])]

    def __str__(self):
        return self.name


# ═════════════════════════════════════════════════════════════
# Conversations + Messages (companion chat persistence)
# ═════════════════════════════════════════════════════════════

class Conversation(models.Model):
    """A user's chat thread with a specific companion."""
    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user       = models.ForeignKey(settings.AUTH_USER_MODEL,
                                   on_delete=models.CASCADE,
                                   related_name="companion_conversations")
    companion  = models.ForeignKey(AiCompanion, on_delete=models.CASCADE,
                                   related_name="conversations")
    title      = models.CharField(max_length=120, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]
        indexes  = [models.Index(fields=["user", "companion", "-updated_at"])]


class ChatMessage(models.Model):
    ROLE_USER      = "user"
    ROLE_ASSISTANT = "assistant"
    ROLE_CHOICES = [(ROLE_USER, "User"), (ROLE_ASSISTANT, "Assistant")]

    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE,
                                     related_name="messages")
    role         = models.CharField(max_length=12, choices=ROLE_CHOICES)
    content      = models.TextField()
    created_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]


# ═════════════════════════════════════════════════════════════
# Image Generation (Pollinations FLUX)
# ═════════════════════════════════════════════════════════════

class ImageGeneration(models.Model):
    """A generated image. Stores prompt + Pollinations URL (URLs are stable)."""

    STATUS_PENDING   = "pending"
    STATUS_SUCCEEDED = "succeeded"
    STATUS_FAILED    = "failed"
    STATUS_CHOICES = [
        (STATUS_PENDING,   "Pending"),
        (STATUS_SUCCEEDED, "Succeeded"),
        (STATUS_FAILED,    "Failed"),
    ]

    MODEL_CHOICES = [
        ("flux",         "FLUX (high quality)"),
        ("turbo",        "Turbo (fast)"),
        ("flux-realism", "FLUX Realism"),
        ("flux-anime",   "FLUX Anime"),
    ]

    id            = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user          = models.ForeignKey(settings.AUTH_USER_MODEL,
                                      on_delete=models.CASCADE,
                                      related_name="image_generations")
    prompt        = models.TextField()
    model         = models.CharField(max_length=20, choices=MODEL_CHOICES, default="flux")
    width         = models.PositiveIntegerField(default=1024)
    height        = models.PositiveIntegerField(default=1024)
    seed          = models.BigIntegerField()
    image_url     = models.URLField(max_length=2000)
    status        = models.CharField(max_length=12, choices=STATUS_CHOICES,
                                     default=STATUS_SUCCEEDED)
    error_message = models.TextField(blank=True)
    created_at    = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes  = [models.Index(fields=["user", "-created_at"])]



# ═════════════════════════════════════════════════════════════
# Sage — personal mentor / wellbeing companion (per-user thread)
# ═════════════════════════════════════════════════════════════

class MentorMessage(models.Model):
    """One message in a user's ongoing private thread with Sage, their
    personal mentor. There is no separate conversation row — each user has
    exactly one continuous mentor thread, and the thread IS the ordered set
    of that user's MentorMessage rows. This keeps "one personal mentor per
    user" simple and lets history persist indefinitely until the user clears it.
    """

    ROLE_USER   = "user"
    ROLE_MENTOR = "mentor"
    ROLE_CHOICES = [(ROLE_USER, "User"), (ROLE_MENTOR, "Mentor")]

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user       = models.ForeignKey(settings.AUTH_USER_MODEL,
                                   on_delete=models.CASCADE,
                                   related_name="mentor_messages")
    role       = models.CharField(max_length=12, choices=ROLE_CHOICES)
    content    = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
        indexes  = [models.Index(fields=["user", "created_at"],
                                 name="ai_mentor_user_created_idx")]

    def __str__(self):
        return f"{self.role} @ {self.created_at:%Y-%m-%d %H:%M}"


# ═════════════════════════════════════════════════════════════
# Knowledge base (RAG) — staff-uploaded study material that Dale
# tutors from. Text is extracted + chunked at upload time; retrieval
# is on-the-fly Postgres full-text search over active chunks.
# ═════════════════════════════════════════════════════════════

class KnowledgeDoc(models.Model):
    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title       = models.CharField(max_length=200)
    subject     = models.CharField(max_length=80, blank=True, default="")
    filename    = models.CharField(max_length=255, blank=True, default="")
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                    null=True, blank=True, related_name="knowledge_docs")
    char_count  = models.PositiveIntegerField(default=0)
    chunk_count = models.PositiveIntegerField(default=0)
    is_active   = models.BooleanField(default=True, db_index=True)
    # How often Dale has drawn on this material to answer a student, and when
    # it last did — the "how Dale responded" signal for the training analytics.
    retrieval_count   = models.PositiveIntegerField(default=0)
    last_retrieved_at = models.DateTimeField(null=True, blank=True)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "ai_knowledge_docs"
        ordering = ["-created_at"]

    def __str__(self):
        return self.title


class KnowledgeChunk(models.Model):
    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    doc        = models.ForeignKey(KnowledgeDoc, on_delete=models.CASCADE,
                                   related_name="chunks")
    ordinal    = models.PositiveIntegerField(default=0)
    content    = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "ai_knowledge_chunks"
        ordering = ["doc", "ordinal"]
        indexes  = [models.Index(fields=["doc", "ordinal"], name="ai_kchunk_doc_ord_idx")]
