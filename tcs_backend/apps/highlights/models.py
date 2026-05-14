import uuid
from django.db import models
from django.conf import settings
from cloudinary.models import CloudinaryField


class Highlight(models.Model):
    """
    A saved story-style highlight reel on a user's profile.
    Mirrors the Post <-> PostMedia shape: Highlight is the parent
    container, HighlightItem is the per-asset child (mirrors PostMedia).
    """
    id    = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                              related_name="highlights")
    title = models.CharField(max_length=80, blank=True)

    # Optional explicit cover. When blank, the serializer falls back to
    # the first item's still so the profile circle always has an image.
    cover = CloudinaryField(
        "image",
        folder="tcs_studenthub/highlights",
        resource_type="image",
        blank=True,
        null=True,
        overwrite=False,
    )

    is_archived = models.BooleanField(default=False)
    created_at  = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "highlights"
        ordering = ["-created_at"]

    def __str__(self):
        return f"Highlight({self.title or self.id}) - {self.owner.display_name}"


class HighlightItem(models.Model):
    """
    One Cloudinary asset inside a Highlight. Mirrors PostMedia: same
    CloudinaryField config, same media_type choices, same `order`
    sequencing. `duration` is the per-item display time (seconds);
    `caption` is the optional overlay text the story viewer renders.
    """
    class MediaType(models.TextChoices):
        IMAGE = "image", "Image"
        VIDEO = "video", "Video"

    id        = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    highlight = models.ForeignKey(Highlight, on_delete=models.CASCADE,
                                  related_name="items")

    file = CloudinaryField(
        "image",
        folder="tcs_studenthub/highlights",
        resource_type="image",
        overwrite=False,
    )

    media_type = models.CharField(max_length=10, choices=MediaType.choices,
                                  default=MediaType.IMAGE)
    order      = models.PositiveSmallIntegerField(default=0)
    duration   = models.PositiveSmallIntegerField(default=5)
    caption    = models.CharField(max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "highlight_items"
        ordering = ["order", "created_at"]

    def __str__(self):
        return f"Item {self.order} of highlight {self.highlight_id}"


# -------------------------------------------------------------
# PER-ITEM LIKES + COMMENTS  (story-slide level engagement)
# Mirrors apps/posts Like + Comment, scoped to a HighlightItem.
# -------------------------------------------------------------

class HighlightItemLike(models.Model):
    """A like on a single HighlightItem (story slide). Mirrors posts.Like."""
    item       = models.ForeignKey(HighlightItem, on_delete=models.CASCADE,
                                   related_name="likes")
    user       = models.ForeignKey(settings.AUTH_USER_MODEL,
                                   on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table        = "highlight_item_likes"
        unique_together = [("item", "user")]

    def __str__(self):
        return f"Like on item {self.item_id} by {self.user_id}"


class HighlightItemComment(models.Model):
    """A comment on a single HighlightItem (story slide). Mirrors posts.Comment."""
    id         = models.UUIDField(primary_key=True, default=uuid.uuid4,
                                  editable=False)
    item       = models.ForeignKey(HighlightItem, on_delete=models.CASCADE,
                                   related_name="comments")
    author     = models.ForeignKey(settings.AUTH_USER_MODEL,
                                   on_delete=models.CASCADE)
    text       = models.TextField(max_length=1000)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "highlight_item_comments"
        ordering = ["created_at"]

    def __str__(self):
        return f"Comment on item {self.item_id} by {self.author_id}"
