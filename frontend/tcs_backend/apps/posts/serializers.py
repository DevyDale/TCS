from django.contrib.auth import get_user_model
from rest_framework import serializers
import cloudinary

from .models import Post, Like, Comment, Bookmark, PostMedia

User = get_user_model()


def _cl(field_value, **opts):
    """Build an optimised Cloudinary URL from a CloudinaryField value."""
    if not field_value:
        return None
    try:
        return cloudinary.CloudinaryImage(str(field_value)).build_url(**opts)
    except Exception:
        return None


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
    Returns each image as {'url': '...', 'type': 'image'}.
    This matches what the Flutter feed reads:
        final media = p['media'] as List? ?? [];
        final imgUrl = (media[0] as Map)['url']
    """
    url = serializers.SerializerMethodField()

    class Meta:
        model  = PostMedia
        fields = ["id", "url", "media_type", "order"]

    def get_url(self, obj):
        # Feed card hero image: 800 px wide, auto height, WebP
        return _cl(obj.file,
                   width=800, crop="limit",
                   fetch_format="auto", quality="auto", secure=True)


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


class PostSerializer(serializers.ModelSerializer):
    author_name   = serializers.CharField(source="author.display_name", read_only=True)
    author_role   = serializers.CharField(source="author.role",         read_only=True)
    author_avatar = serializers.SerializerMethodField()

    # media is now a LIST of objects, matching Flutter's:
    #   final media = p['media'] as List? ?? [];
    #   final imgUrl = (media[0] as Map)['url'];
    media = PostMediaSerializer(source="media_files", many=True, read_only=True)

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
            "media",                              # ← now a list
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
    class Meta:
        model  = Post
        fields = ["post_type", "content", "visibility",
                  "location", "background_color", "group", "event"]