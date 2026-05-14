from rest_framework import serializers

# Reuse the posts URL builders so highlight media URLs are built
# byte-identically to post media URLs.
from apps.posts.serializers import _cl, _cl_video, _cl_video_thumb

from .models import Highlight, HighlightItem


def _cover_url(highlight):
    """
    Cover thumbnail for a highlight: the explicit cover if set, else the
    first item's still. Always 400x400 fill so the profile circle and
    feed card crop consistently.
    """
    if highlight.cover:
        return _cl(highlight.cover, width=400, height=400, crop="fill",
                   fetch_format="auto", quality="auto", secure=True)
    first = highlight.items.first()
    if not first:
        return None
    if first.media_type == "video":
        return _cl_video_thumb(first.file, width=400, crop="limit",
                               quality="auto", secure=True)
    return _cl(first.file, width=400, height=400, crop="fill",
               fetch_format="auto", quality="auto", secure=True)


class HighlightItemSerializer(serializers.ModelSerializer):
    """
    Mirrors PostMediaSerializer - one item as
        {id, url, thumbnail_url, media_type, order, duration}
    Images: url is an 800px auto-WebP hero, thumbnail_url is null.
    Videos: url is the streamable mp4/webm, thumbnail_url is a
    Cloudinary poster frame.
    """
    url           = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()

    class Meta:
        model  = HighlightItem
        fields = ["id", "url", "thumbnail_url", "media_type", "order", "duration"]

    def get_url(self, obj):
        if obj.media_type == "video":
            return _cl_video(obj.file, fetch_format="auto", quality="auto",
                             secure=True)
        return _cl(obj.file, width=800, crop="limit",
                   fetch_format="auto", quality="auto", secure=True)

    def get_thumbnail_url(self, obj):
        if obj.media_type != "video":
            return None
        return _cl_video_thumb(obj.file, width=800, crop="limit",
                               quality="auto", secure=True)


class HighlightSerializer(serializers.ModelSerializer):
    """
    Full highlight + ordered items - the shape the story viewer
    (HighlightStory.fromJson) consumes from GET /highlights/<id>/.
    """
    owner_name   = serializers.CharField(source="owner.display_name", read_only=True)
    owner_avatar = serializers.SerializerMethodField()
    cover_url    = serializers.SerializerMethodField()
    item_count   = serializers.SerializerMethodField()
    items        = HighlightItemSerializer(many=True, read_only=True)

    class Meta:
        model  = Highlight
        fields = ["id", "title", "owner_name", "owner_avatar",
                  "cover_url", "item_count", "items",
                  "is_archived", "created_at", "updated_at"]
        read_only_fields = ["id", "owner_name", "owner_avatar",
                            "cover_url", "item_count", "items",
                            "created_at", "updated_at"]

    def get_owner_avatar(self, obj):
        return _cl(obj.owner.avatar, width=200, height=200, crop="fill",
                   gravity="face", fetch_format="auto", quality="auto",
                   secure=True)

    def get_item_count(self, obj):
        return obj.items.count()

    def get_cover_url(self, obj):
        return _cover_url(obj)


class HighlightCompactSerializer(serializers.ModelSerializer):
    """
    Lightweight form for the profile highlights row - no full items
    list, just enough to render the circle + title + count.
    """
    cover_url  = serializers.SerializerMethodField()
    item_count = serializers.SerializerMethodField()

    class Meta:
        model  = Highlight
        fields = ["id", "title", "cover_url", "item_count", "created_at"]
        read_only_fields = fields

    def get_item_count(self, obj):
        return obj.items.count()

    def get_cover_url(self, obj):
        return _cover_url(obj)


class CreateHighlightSerializer(serializers.ModelSerializer):
    """Create/rename flow - client POSTs {title}; items uploaded after."""
    class Meta:
        model  = Highlight
        fields = ["title", "is_archived"]
