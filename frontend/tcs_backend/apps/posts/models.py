import uuid
from django.db import models
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