# apps/accounts/serializers_other.py
#
# Phase 3 — separate serializer for the "other user profile" view.
# Applies privacy gates: bio and interests are only included when the
# owner has them set to public. The viewer's own profile uses the
# existing UserProfileSerializer (full fields, no gating).
#
# Imported and wired into apps/accounts/views.py — see views patch.

from rest_framework import serializers
import cloudinary

from django.contrib.auth import get_user_model

User = get_user_model()


def _cloudinary_url(field_value, **opts):
    if not field_value:
        return None
    try:
        return cloudinary.CloudinaryImage(str(field_value)).build_url(**opts)
    except Exception:
        return None


class OtherUserProfileSerializer(serializers.ModelSerializer):
    """
    Profile view served when user A looks at user B (where A != B).

    Privacy rules (Phase 3 spec 3.3):
      - profile + cover image, name, preferred name, role            → always visible
      - bio                                                          → only if `privacy_settings.bio_public` is true
      - interests                                                    → only if `interests_visibility` == 'public'
      - followers / following / posts counts                         → always visible
      - is_following (whether the viewer follows this user)          → always visible

    Sensitive fields (email, username, phone, fcm_token, gamer_tag,
    notification_settings, privacy_settings, xp/level/tokens, location,
    website) are intentionally NOT included.
    """

    name              = serializers.CharField(source="display_name", read_only=True)
    full_name         = serializers.CharField(source="name",         read_only=True)
    avatar_url        = serializers.SerializerMethodField()
    cover_url         = serializers.SerializerMethodField()
    bio               = serializers.SerializerMethodField()
    interests         = serializers.SerializerMethodField()
    bio_public        = serializers.SerializerMethodField()
    interests_public  = serializers.SerializerMethodField()
    followers_count   = serializers.SerializerMethodField()
    following_count   = serializers.SerializerMethodField()
    posts_count       = serializers.SerializerMethodField()
    is_following      = serializers.SerializerMethodField()
    is_self           = serializers.SerializerMethodField()

    class Meta:
        model  = User
        fields = [
            "user_id", "role",
            "name", "full_name", "preferred_name",
            "avatar_url", "cover_url",
            "bio", "interests",
            "bio_public", "interests_public",
            "followers_count", "following_count", "posts_count",
            "is_following", "is_self", "is_verified",
        ]
        read_only_fields = fields

    # ── Media URLs ───────────────────────────────────────────

    def get_avatar_url(self, obj):
        return _cloudinary_url(
            obj.avatar,
            width=400, height=400, crop="fill", gravity="face",
            fetch_format="auto", quality="auto", secure=True,
        )

    def get_cover_url(self, obj):
        return _cloudinary_url(
            obj.cover,
            width=1200, height=400, crop="fill",
            fetch_format="auto", quality="auto", secure=True,
        )

    # ── Privacy gates ────────────────────────────────────────

    def _bio_is_public(self, obj):
        prefs = obj.privacy_settings or {}
        # Default: bios are public unless the user has explicitly hidden them.
        return prefs.get("bio_public", True) is True

    def _interests_are_public(self, obj):
        # Field added in Phase 3 migration; defaults to 'public' for existing rows.
        vis = getattr(obj, "interests_visibility", "public") or "public"
        return vis == "public"

    def get_bio(self, obj):
        return obj.bio if self._bio_is_public(obj) else ""

    def get_interests(self, obj):
        return obj.interests if self._interests_are_public(obj) else []

    def get_bio_public(self, obj):
        return self._bio_is_public(obj)

    def get_interests_public(self, obj):
        return self._interests_are_public(obj)

    # ── Counts & relationship ────────────────────────────────

    def get_followers_count(self, obj):
        return obj.followers.count()

    def get_following_count(self, obj):
        return obj.following.count()

    def get_posts_count(self, obj):
        # Posts where this user is the author — across post types.
        # Lazy import to avoid circular dependency at module load.
        from apps.posts.models import Post
        return Post.objects.filter(author=obj, is_flagged=False).count()

    def get_is_following(self, obj):
        req = self.context.get("request")
        if req and req.user.is_authenticated:
            return obj.followers.filter(pk=req.user.pk).exists()
        return False

    def get_is_self(self, obj):
        req = self.context.get("request")
        return bool(req and req.user.is_authenticated and req.user.pk == obj.pk)
