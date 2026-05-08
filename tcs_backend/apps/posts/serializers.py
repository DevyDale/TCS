from django.contrib.auth import get_user_model
from rest_framework import serializers
import cloudinary

from .models import Post, Like, Comment, Bookmark, PostMedia, Hashtag, Feeling

User = get_user_model()


def _cl(field_value, **opts):
    """Build an optimised Cloudinary IMAGE URL from a CloudinaryField value."""
    if not field_value:
        return None
    try:
        return cloudinary.CloudinaryImage(str(field_value)).build_url(**opts)
    except Exception:
        return None


def _cl_video(field_value, **opts):
    """
    Build a Cloudinary VIDEO URL. Used for the streaming `url` field
    on video PostMedia rows. Defaults: secure, auto format/quality.
    """
    if not field_value:
        return None
    try:
        return cloudinary.CloudinaryVideo(str(field_value)).build_url(**opts)
    except Exception:
        return None


def _cl_video_thumb(field_value, **opts):
    """
    Build a JPEG thumbnail URL for a Cloudinary video asset. Cloudinary
    auto-picks a representative frame when start_offset='auto' is set
    (its smart-keyframe algorithm). The URL is just the video's URL
    with format=jpg, which Cloudinary serves back as a still image.
    """
    if not field_value:
        return None
    try:
        return cloudinary.CloudinaryVideo(str(field_value)).build_url(
            format       = "jpg",
            start_offset = "auto",
            **opts,
        )
    except Exception:
        return None


# ─────────────────────────────────────────────────────────────
# HASHTAGS
# ─────────────────────────────────────────────────────────────

class HashtagSerializer(serializers.ModelSerializer):
    """Full hashtag — used on detail and list endpoints."""
    class Meta:
        model  = Hashtag
        fields = ["slug", "display", "posts_count",
                  "first_seen_at", "last_used_at"]
        read_only_fields = fields


class HashtagCompactSerializer(serializers.ModelSerializer):
    """Lightweight nested form — embedded inside PostSerializer."""
    class Meta:
        model  = Hashtag
        fields = ["slug", "display"]
        read_only_fields = fields


# ─────────────────────────────────────────────────────────────
# FEELINGS
# ─────────────────────────────────────────────────────────────

class FeelingSerializer(serializers.ModelSerializer):
    """Full feeling — used on the picker endpoint /api/feelings/."""
    class Meta:
        model  = Feeling
        fields = ["slug", "label", "emoji", "category", "sort_order"]
        read_only_fields = fields


class FeelingCompactSerializer(serializers.ModelSerializer):
    """Lightweight nested form — embedded inside PostSerializer."""
    class Meta:
        model  = Feeling
        fields = ["slug", "label", "emoji"]
        read_only_fields = fields


# ─────────────────────────────────────────────────────────────
# AUTHOR / MEDIA / COMMENT
# ─────────────────────────────────────────────────────────────

class AuthorSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()
    name       = serializers.CharField(source="display_name")

    class Meta:
        model  = User
        fields = ["user_id", "name", "role", "avatar_url", "is_verified", "level"]

    def get_avatar_url(self, obj):
        return _cl(obj.avatar,
                   width=200, height=200, crop="fill", gravity="face",
                   fetch_format="auto", quality="auto", secure=True)


class PostMediaSerializer(serializers.ModelSerializer):
    """
    Returns each media item as
        {'url': '...', 'thumbnail_url': '...', 'media_type': 'image'|'video', ...}

    Flutter feed reads:
        final media   = p['media'] as List? ?? [];
        final first   = (media[0] as Map);
        final url     = first['url'];
        final type    = first['media_type'];
        final thumb   = first['thumbnail_url'];   // null for images

    For images, thumbnail_url is null — the regular url already serves
    a sized thumbnail (800px wide, auto WebP). For videos the URL is
    the streamable mp4/webm and thumbnail_url is a JPEG poster frame
    Cloudinary picks automatically.
    """
    url           = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()

    class Meta:
        model  = PostMedia
        fields = ["id", "url", "thumbnail_url", "media_type", "order"]

    def get_url(self, obj):
        if obj.media_type == "video":
            # Streamable video URL — auto format and quality let
            # Cloudinary pick mp4 / webm based on the client.
            return _cl_video(obj.file,
                             fetch_format="auto", quality="auto",
                             secure=True)
        # Image: 800 px wide hero, auto WebP, lazy-resized.
        return _cl(obj.file,
                   width=800, crop="limit",
                   fetch_format="auto", quality="auto", secure=True)

    def get_thumbnail_url(self, obj):
        if obj.media_type != "video":
            return None
        return _cl_video_thumb(obj.file,
                               width=800, crop="limit",
                               quality="auto", secure=True)


class CommentSerializer(serializers.ModelSerializer):
    author_name   = serializers.CharField(source="author.display_name", read_only=True)
    author_avatar = serializers.SerializerMethodField()
    reply_count   = serializers.SerializerMethodField()

    class Meta:
        model  = Comment
        fields = [
            "id", "post_id", "author_name", "author_avatar",
            "text", "parent_id", "likes_count", "reply_count",
            "is_deleted", "created_at",
        ]
        read_only_fields = ["id", "author_name", "author_avatar",
                            "likes_count", "is_deleted", "created_at"]

    def get_author_avatar(self, obj):
        return _cl(obj.author.avatar,
                   width=100, height=100, crop="fill", gravity="face",
                   fetch_format="auto", quality="auto", secure=True)

    def get_reply_count(self, obj):
        return obj.replies.filter(is_deleted=False).count()


# ─────────────────────────────────────────────────────────────
# POSTS
# ─────────────────────────────────────────────────────────────

class PostSerializer(serializers.ModelSerializer):
    author_name   = serializers.CharField(source="author.display_name", read_only=True)
    author_role   = serializers.CharField(source="author.role",         read_only=True)
    author_avatar = serializers.SerializerMethodField()

    # media is a LIST of {url, thumbnail_url, media_type, order, id}.
    # Mixed image + video posts are supported (one row per asset).
    media     = PostMediaSerializer(source="media_files", many=True, read_only=True)
    hashtags  = HashtagCompactSerializer(many=True, read_only=True)
    feeling   = FeelingCompactSerializer(read_only=True)

    is_liked      = serializers.SerializerMethodField()
    is_bookmarked = serializers.SerializerMethodField()

    like_count    = serializers.IntegerField(source="likes_count",    read_only=True)
    comment_count = serializers.IntegerField(source="comments_count", read_only=True)
    share_count   = serializers.IntegerField(source="shares_count",   read_only=True)

    class Meta:
        model  = Post
        fields = [
            "id", "author_name", "author_role", "author_avatar",
            "post_type", "content", "visibility",
            "media", "hashtags", "feeling",
            "background_color", "location",
            "like_count", "comment_count", "share_count", "views_count",
            "is_liked", "is_bookmarked", "is_pinned", "is_flagged",
            "created_at", "updated_at",
        ]
        read_only_fields = [
            "id", "author_name", "author_role", "author_avatar",
            "like_count", "comment_count", "share_count", "views_count",
            "created_at", "updated_at",
        ]

    def get_is_liked(self, obj):
        req = self.context.get("request")
        if req and req.user.is_authenticated:
            return Like.objects.filter(post=obj, user=req.user).exists()
        return False

    def get_is_bookmarked(self, obj):
        req = self.context.get("request")
        if req and req.user.is_authenticated:
            return Bookmark.objects.filter(post=obj, user=req.user).exists()
        return False

    def get_author_avatar(self, obj):
        return _cl(obj.author.avatar,
                   width=200, height=200, crop="fill", gravity="face",
                   fetch_format="auto", quality="auto", secure=True)

class CreatePostSerializer(serializers.ModelSerializer):
    # Client sends feeling as a slug string ("happy"), not a pk.
    # Inactive feelings are excluded from the queryset so the API
    # rejects retired feelings rather than letting them sneak in.
    feeling = serializers.SlugRelatedField(
        slug_field = "slug",
        queryset   = Feeling.objects.filter(is_active=True),
        required   = False,
        allow_null = True,
    )

    class Meta:
        model  = Post
        # `club` is optional. When the client posts from inside a
        # club screen, it includes the club's UUID and the post is
        # scoped to that club; otherwise it's a regular user post.
        fields = ["post_type", "content", "visibility",
                  "location", "background_color",
                  "group", "event", "club",
                  "feeling"]

    def validate_club(self, value):
        """
        Only members of a club can post into it. Admins (executive,
        president) are members too, so this also covers them.
        """
        if value is None:
            return value
        request = self.context.get("request")
        user = getattr(request, "user", None)
        if user is None or not user.is_authenticated:
            raise serializers.ValidationError(
                "Authentication required to post into a club.")
        from apps.clubs.models import ClubMember
        is_member = ClubMember.objects.filter(
            club=value, user=user, status="active"
        ).exists()
        if not is_member:
            raise serializers.ValidationError(
                "You must be an active member of this club to post into it.")
        return value