from rest_framework import serializers

# Reuse the posts URL builders so highlight media URLs are built
# byte-identically to post media URLs.
from apps.posts.serializers import _cl, _cl_video, _cl_video_thumb

from .models import Highlight, HighlightItem, HighlightItemComment


def _cover_url(highlight):
    """Explicit cover if set, else the first item's still. 400x400 fill."""
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


class HighlightItemCommentSerializer(serializers.ModelSerializer):
    """
    One comment on a story item - shaped for the story viewer's comment
    sheet. `text` is the only writable field; the view supplies author
    and item on create.
    """
    author_name   = serializers.CharField(source="author.display_name",
                                           read_only=True)
    author_avatar = serializers.SerializerMethodField()

    class Meta:
        model  = HighlightItemComment
        fields = ["id", "author_name", "author_avatar", "text", "created_at"]
        read_only_fields = ["id", "author_name", "author_avatar", "created_at"]

    def get_author_avatar(self, obj):
        return _cl(obj.author.avatar, width=200, height=200, crop="fill",
                   gravity="face", fetch_format="auto", quality="auto",
                   secure=True)


class HighlightItemSerializer(serializers.ModelSerializer):
    """
    One story item, shaped for HighlightStory.fromJson:
        {id, url, thumbnail_url, media_type, order, duration,
         caption, author_name, author_avatar,
         like_count, comment_count, is_liked, created_at}
    """
    url           = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()
    author_name   = serializers.SerializerMethodField()
    author_avatar = serializers.SerializerMethodField()
    like_count    = serializers.SerializerMethodField()
    comment_count = serializers.SerializerMethodField()
    is_liked      = serializers.SerializerMethodField()

    class Meta:
        model  = HighlightItem
        fields = ["id", "url", "thumbnail_url", "media_type", "order",
                  "duration", "caption", "author_name", "author_avatar",
                  "like_count", "comment_count", "is_liked", "created_at"]

    def _owner(self, obj):
        return self.context.get("_owner") or obj.highlight.owner

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

    def get_author_name(self, obj):
        return self._owner(obj).display_name

    def get_author_avatar(self, obj):
        return _cl(self._owner(obj).avatar, width=200, height=200,
                   crop="fill", gravity="face", fetch_format="auto",
                   quality="auto", secure=True)

    def get_like_count(self, obj):
        return obj.likes.count()

    def get_comment_count(self, obj):
        return obj.comments.count()

    def get_is_liked(self, obj):
        req = self.context.get("request")
        if req and req.user.is_authenticated:
            return obj.likes.filter(user=req.user).exists()
        return False


class HighlightSerializer(serializers.ModelSerializer):
    """Full highlight + ordered items - consumed by HighlightStory.fromJson."""
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

    def to_representation(self, instance):
        self.context["_owner"] = instance.owner
        return super().to_representation(instance)

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
    Lightweight form for the profile highlights row AND the campus
    feed's Highlights row. owner_name / owner_id let the feed label
    each circle with whose highlight it is.
    """
    owner_name = serializers.CharField(source="owner.display_name",
                                        read_only=True)
    owner_id   = serializers.CharField(source="owner.user_id",
                                        read_only=True)
    cover_url  = serializers.SerializerMethodField()
    item_count = serializers.SerializerMethodField()

    class Meta:
        model  = Highlight
        fields = ["id", "title", "owner_name", "owner_id",
                  "cover_url", "item_count", "created_at"]
        read_only_fields = fields

    def get_item_count(self, obj):
        return obj.items.count()

    def get_cover_url(self, obj):
        return _cover_url(obj)


class CreateHighlightSerializer(serializers.ModelSerializer):
    """Create / rename / archive flow."""
    class Meta:
        model  = Highlight
        fields = ["title", "is_archived"]
