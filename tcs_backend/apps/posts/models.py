import uuid
import re
from django.db import models, transaction
from django.conf import settings
from django.utils import timezone
from cloudinary.models import CloudinaryField


class Post(models.Model):
    class PostType(models.TextChoices):
        POST         = "post",         "Post"
        FWEET        = "fweet",        "Fweet"
        ANNOUNCEMENT = "announcement", "Announcement"
        ARCADE_CLIP  = "arcade_clip",  "Arcade Clip"

    class Visibility(models.TextChoices):
        PUBLIC    = "public",    "Public"
        FOLLOWERS = "followers", "Followers"
        PRIVATE   = "private",   "Private"

    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    author     = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                   related_name="posts")
    post_type  = models.CharField(max_length=20, choices=PostType.choices,
                                  default=PostType.POST)
    content    = models.TextField(blank=True)
    visibility = models.CharField(max_length=12, choices=Visibility.choices,
                                  default=Visibility.PUBLIC)

    # Single legacy media field removed.
    # Media is now handled by PostMedia (one-to-many) below,
    # which supports up to 5 images per post.
    # The background_color field is kept for Fweets.
    background_color = models.CharField(max_length=20, blank=True)
    location         = models.CharField(max_length=120, blank=True)

    tagged_users = models.ManyToManyField(settings.AUTH_USER_MODEL, blank=True,
                                          related_name="post_tags")

    # Hashtags are extracted from `content` on create/update via
    # attach_hashtags() below. The string reference "Hashtag" is used
    # because Hashtag is declared later in this same module.
    hashtags     = models.ManyToManyField("Hashtag", blank=True,
                                          related_name="posts")

    group  = models.ForeignKey("groups.Group",  null=True, blank=True,
                               on_delete=models.SET_NULL, related_name="group_posts")
    event  = models.ForeignKey("events.Event",  null=True, blank=True,
                               on_delete=models.SET_NULL, related_name="event_posts")

    is_flagged = models.BooleanField(default=False)
    is_pinned  = models.BooleanField(default=False)

    likes_count    = models.PositiveIntegerField(default=0)
    comments_count = models.PositiveIntegerField(default=0)
    shares_count   = models.PositiveIntegerField(default=0)
    views_count    = models.PositiveIntegerField(default=0)

    expires_at = models.DateTimeField(null=True, blank=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "posts"
        ordering = ["-created_at"]

    def __str__(self):
        return f"[{self.post_type}] {self.author.display_name}: {self.content[:60]}"

    @property
    def is_expired(self):
        if self.expires_at:
            return timezone.now() > self.expires_at
        return False


class PostMedia(models.Model):
    """
    Stores one Cloudinary image per row.
    A post can have up to 5 images (enforced at the view layer).
    The `order` field controls display sequence in the carousel.
    """
    class MediaType(models.TextChoices):
        IMAGE = "image", "Image"
        VIDEO = "video", "Video"  # reserved for future use

    id   = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name="media_files")

    # CloudinaryField stores the Cloudinary public_id in the DB column.
    # The actual bytes live in Cloudinary — never in Postgres.
    # django_cleanup deletes the Cloudinary asset when the row is deleted.
    file = CloudinaryField(
        "image",
        folder="tcs_studenthub/posts",
        resource_type="image",
        # Allow overwrite=False here so each upload gets a unique public_id
        overwrite=False,
    )

    media_type = models.CharField(max_length=10, choices=MediaType.choices,
                                  default=MediaType.IMAGE)
    order      = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table  = "post_media"
        ordering  = ["order", "created_at"]

    def __str__(self):
        return f"Media {self.order} for post {self.post_id}"


class Like(models.Model):
    post       = models.ForeignKey(Post, on_delete=models.CASCADE, related_name="likes")
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table       = "post_likes"
        unique_together = [("post", "user")]


class Comment(models.Model):
    id     = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    post   = models.ForeignKey(Post, on_delete=models.CASCADE, related_name="comments")
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    text   = models.TextField(max_length=1000)
    parent = models.ForeignKey("self", null=True, blank=True,
                               on_delete=models.CASCADE, related_name="replies")
    likes_count = models.PositiveIntegerField(default=0)
    is_deleted  = models.BooleanField(default=False)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "post_comments"
        ordering = ["created_at"]


class Bookmark(models.Model):
    post       = models.ForeignKey(Post, on_delete=models.CASCADE, related_name="bookmarks")
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table       = "post_bookmarks"
        unique_together = [("post", "user")]


class PostFlag(models.Model):
    post       = models.ForeignKey(Post, on_delete=models.CASCADE, related_name="flags")
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    reason     = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table       = "post_flags"
        unique_together = [("post", "user")]


# ─────────────────────────────────────────────────────────────
# HASHTAGS
# ─────────────────────────────────────────────────────────────

# Matches "#word" — letters, digits, underscores. Won't match "#"
# alone, "###", or punctuation-only "#-".
_HASHTAG_RE = re.compile(r"#([A-Za-z0-9_]+)")


def extract_hashtags(content: str):
    """
    Pull (slug, display) pairs out of arbitrary text. Returns up to
    10 unique pairs in first-seen order. Slug is lowercase canonical
    form ("openday"); display preserves casing of the first sighting
    ("OpenDay") for nicer rendering.
    """
    if not content:
        return []
    seen = {}
    for m in _HASHTAG_RE.finditer(content):
        word = m.group(1)
        slug = word.lower()
        if slug in seen:
            continue
        seen[slug] = word
        if len(seen) >= 10:
            break
    return list(seen.items())

class Feeling(models.Model):
    """
    A pickable feeling like 😊 happy or 📚 studying. Backend-driven
    so admins can add/retire feelings without an app rebuild.
 
    `category` is a soft grouping (mood / activity / state) — the
    create-post picker can use it to section the list. `sort_order`
    is curated, not alphabetical, so commonly-used moods bubble up.
    `is_active=False` retires a feeling from the picker without
    breaking historical posts that already used it (FK is SET_NULL).
 
    Seeded via the data migration in 0005_add_feelings.
    """
    slug       = models.SlugField(max_length=40, unique=True, db_index=True)
    label      = models.CharField(max_length=40)
    emoji      = models.CharField(max_length=8)
    category   = models.CharField(max_length=20, blank=True)
    sort_order = models.PositiveSmallIntegerField(default=0)
    is_active  = models.BooleanField(default=True)
 
    class Meta:
        db_table = "feelings"
        ordering = ["sort_order", "label"]
 
    def __str__(self):
        return f"{self.emoji} {self.label}"

class Hashtag(models.Model):
    """
    Normalized hashtag. Slug is the canonical lowercase form so
    '#OpenDay', '#openday', and '#OPENDAY' all collide on slug
    'openday'. `display` keeps the FIRST sighting's casing.
    """
    slug          = models.SlugField(max_length=80, unique=True, db_index=True)
    display       = models.CharField(max_length=80)
    posts_count   = models.PositiveIntegerField(default=0, db_index=True)
    first_seen_at = models.DateTimeField(auto_now_add=True)
    last_used_at  = models.DateTimeField(auto_now=True, db_index=True)

    class Meta:
        db_table = "hashtags"
        ordering = ["-last_used_at"]

    def __str__(self):
        return f"#{self.display}"


@transaction.atomic
def attach_hashtags(post, content):
    """
    Idempotent. Parse `content`, get_or_create Hashtag rows, and
    sync the M2M with `post`. Bumps posts_count + last_used_at on
    add and decrements on remove (for edits where the user deleted
    a hashtag from the body).
    """
    pairs     = extract_hashtags(content)
    new_slugs = {slug for slug, _ in pairs}
    old_slugs = set(post.hashtags.values_list("slug", flat=True))

    # Remove dropped hashtags
    for slug in old_slugs - new_slugs:
        try:
            tag = Hashtag.objects.get(slug=slug)
            post.hashtags.remove(tag)
            Hashtag.objects.filter(pk=tag.pk).update(
                posts_count=models.F("posts_count") - 1
            )
        except Hashtag.DoesNotExist:
            pass

    # Add new hashtags
    for slug, display in pairs:
        if slug in old_slugs:
            continue
        tag, _ = Hashtag.objects.get_or_create(
            slug=slug,
            defaults={"display": display},
        )
        post.hashtags.add(tag)
        Hashtag.objects.filter(pk=tag.pk).update(
            posts_count=models.F("posts_count") + 1,
            last_used_at=timezone.now(),
        )