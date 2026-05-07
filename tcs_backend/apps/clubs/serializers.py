"""Phase 5 Slice 1 — DRF serializers for clubs."""
from rest_framework import serializers

from .models import Club, ClubMember


# ─────────────────────────────────────────────────────────────
# CLUB
# ─────────────────────────────────────────────────────────────

class ClubSerializer(serializers.ModelSerializer):
    """
    The default read serializer used everywhere on the read side.

    Adds three computed fields the frontend cares about:
      • cover_url / logo_url — Cloudinary URLs (or null)
      • membership          — full membership object for the request user
                              (is_member / is_pending / is_admin / role / status)
      • is_member / is_admin — convenience top-level flags
    """
    cover_url  = serializers.SerializerMethodField()
    logo_url   = serializers.SerializerMethodField()
    membership = serializers.SerializerMethodField()
    is_member  = serializers.SerializerMethodField()
    is_admin   = serializers.SerializerMethodField()

    class Meta:
        model  = Club
        fields = [
            "id", "name", "slug", "tagline", "category",
            "description", "mission", "rules",
            "contact_email", "contact_phone",
            "cover_url", "logo_url",
            "is_verified", "is_public", "requires_approval", "is_active",
            "members_count",
            "membership", "is_member", "is_admin",
            "created_at", "updated_at",
        ]
        read_only_fields = [
            "id", "slug", "members_count",
            "is_verified", "is_active",
            "membership", "is_member", "is_admin",
            "created_at", "updated_at",
        ]

    # ── Helpers ──────────────────────────────────────────────

    def _request_user(self):
        req = self.context.get("request")
        return req.user if req and req.user.is_authenticated else None

    def _membership(self, obj):
        u = self._request_user()
        if not u:
            return None
        try:
            return ClubMember.objects.get(club=obj, user=u)
        except ClubMember.DoesNotExist:
            return None

    # ── Method fields ────────────────────────────────────────

    def get_cover_url(self, obj):
        return obj.cover.url if obj.cover else None

    def get_logo_url(self, obj):
        return obj.logo.url if obj.logo else None

    def get_membership(self, obj):
        m = self._membership(obj)
        if m is None:
            return {
                "is_member":  False,
                "is_pending": False,
                "is_admin":   False,
                "role":       None,
                "status":     None,
            }
        return {
            "is_member":  m.status == ClubMember.Status.ACTIVE,
            "is_pending": m.status == ClubMember.Status.PENDING,
            "is_admin":   m.is_admin,
            "role":       m.role,
            "status":     m.status,
        }

    def get_is_member(self, obj):
        return self.get_membership(obj)["is_member"]

    def get_is_admin(self, obj):
        return self.get_membership(obj)["is_admin"]


# ─────────────────────────────────────────────────────────────
# CLUB CREATE
# ─────────────────────────────────────────────────────────────

class ClubCreateSerializer(serializers.ModelSerializer):
    """Used by POST /api/clubs/ — creator is auto-promoted to PRESIDENT."""

    class Meta:
        model  = Club
        fields = [
            "name", "tagline", "description", "mission", "rules",
            "contact_email", "contact_phone",
            "category", "is_public", "requires_approval",
        ]

    def validate_name(self, v):
        v = (v or "").strip()
        if not v:
            raise serializers.ValidationError("Name is required.")
        if Club.objects.filter(name__iexact=v).exists():
            raise serializers.ValidationError(
                "A club with that name already exists.")
        return v


# ─────────────────────────────────────────────────────────────
# MEMBERSHIP
# ─────────────────────────────────────────────────────────────

class ClubMemberSerializer(serializers.ModelSerializer):
    """Read-only member card used by GET /api/clubs/<id>/members/."""
    user_id    = serializers.CharField(source="user.user_id",     read_only=True)
    name       = serializers.CharField(source="user.display_name", read_only=True)
    user_role  = serializers.CharField(source="user.role",         read_only=True)
    avatar_url = serializers.SerializerMethodField()
    is_admin   = serializers.SerializerMethodField()

    class Meta:
        model  = ClubMember
        fields = [
            "user_id", "name", "avatar_url", "user_role",
            "role", "status", "is_admin", "joined_at",
        ]

    def get_avatar_url(self, obj):
        return obj.user.avatar.url if obj.user.avatar else None

    def get_is_admin(self, obj):
        return obj.is_admin
