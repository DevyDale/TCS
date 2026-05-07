# apps/clubs/views.py
from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import generics, permissions, serializers, status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response

from .models import Club, ClubMember

User = get_user_model()


# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

def _membership(club, user):
    if not user or not user.is_authenticated:
        return None
    return ClubMember.objects.filter(club=club, user=user).first()


def _is_admin(club, user):
    """Executive or president can manage the club."""
    m = _membership(club, user)
    return bool(m and m.status == "active"
                  and m.role in ("executive", "president"))


def _is_president(club, user):
    m = _membership(club, user)
    return bool(m and m.status == "active" and m.role == "president")


def _active_qs():
    return Club.objects.filter(is_active=True)


# ─────────────────────────────────────────────────────────────
# Serializers
# ─────────────────────────────────────────────────────────────

class ClubSerializer(serializers.ModelSerializer):
    cover_url     = serializers.SerializerMethodField()
    logo_url      = serializers.SerializerMethodField()
    membership    = serializers.SerializerMethodField()
    pending_count = serializers.SerializerMethodField()

    class Meta:
        model  = Club
        fields = [
            "id", "name", "tagline", "description",
            "mission", "rules", "purpose",
            "contact_email", "contact_phone",
            "category", "theme_icon",
            "cover_url", "logo_url",
            "is_public", "requires_approval", "is_verified",
            "members_count",
            "membership",       # nested dict — frontend expects this
            "pending_count",
            "created_at", "updated_at",
        ]
        read_only_fields = [
            "id", "members_count", "is_verified",
            "created_at", "updated_at",
        ]

    # ─── Image URLs ─────────────────────────────────────────

    def _abs(self, file_field):
        if not file_field:
            return None
        req = self.context.get("request")
        try:
            return req.build_absolute_uri(file_field.url) if req else file_field.url
        except Exception:
            return None

    def get_cover_url(self, obj): return self._abs(obj.cover)
    def get_logo_url(self,  obj): return self._abs(obj.logo)

    # ─── Per-user state — bundled into a single nested dict ──

    def _me(self):
        req = self.context.get("request")
        return req.user if req and req.user.is_authenticated else None

    def get_membership(self, obj):
        """
        Returns a dict shape the frontend reads as `club['membership']`:
            { is_member, is_pending, is_admin, role, status }
        """
        u = self._me()
        if not u:
            return {
                "is_member":  False,
                "is_pending": False,
                "is_admin":   False,
                "role":       None,
                "status":     None,
            }
        m = ClubMember.objects.filter(club=obj, user=u).first()
        is_admin = bool(
            m and m.status == "active"
              and m.role in ("executive", "president"))
        return {
            "is_member":  bool(m and m.status == "active"),
            "is_pending": bool(m and m.status == "pending"),
            "is_admin":   is_admin,
            "role":       m.role if m and m.status == "active" else None,
            "status":     m.status if m else None,
        }

    def get_pending_count(self, obj):
        # Hide from non-admins (don't leak counts to outsiders).
        if not _is_admin(obj, self._me()):
            return 0
        return obj.memberships.filter(status="pending").count()


class ClubMemberSerializer(serializers.ModelSerializer):
    user_id    = serializers.CharField(source="user.user_id")
    name       = serializers.CharField(source="user.display_name")
    user_role  = serializers.CharField(source="user.role")  # student/staff
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model  = ClubMember
        fields = [
            "user_id", "name", "user_role", "avatar_url",
            "status", "role", "joined_at",
        ]

    def get_avatar_url(self, obj):
        u = obj.user
        avatar = getattr(u, "avatar", None) or getattr(u, "avatar_url", None)
        if not avatar:
            return None
        if isinstance(avatar, str):
            return avatar
        try:
            req = self.context.get("request")
            return req.build_absolute_uri(avatar.url) if req else avatar.url
        except Exception:
            return None


class ClubCreateSerializer(serializers.ModelSerializer):
    """
    Used for create + update.
    Fields the create form posts: name, tagline, description, category,
    is_public, requires_approval. Admins can also patch mission, rules,
    purpose, contact_email, contact_phone via the same endpoint.
    """
    class Meta:
        model  = Club
        fields = [
            "name", "tagline", "description",
            "mission", "rules", "purpose",
            "contact_email", "contact_phone",
            "category",
            "is_public", "requires_approval",
        ]


# ─────────────────────────────────────────────────────────────
# List + Create
# ─────────────────────────────────────────────────────────────

class ClubListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/clubs/?filter=all|mine|pending|admin&q=&category=&page=
    POST /api/clubs/      (creator becomes PRESIDENT)
    """
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        return (ClubCreateSerializer if self.request.method == "POST"
                else ClubSerializer)

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        u   = self.request.user
        f   = self.request.query_params.get("filter", "all")
        q   = self.request.query_params.get("q", "").strip()
        cat = self.request.query_params.get("category", "").strip()

        qs = _active_qs()

        if f == "mine":
            qs = qs.filter(memberships__user=u, memberships__status="active")
        elif f == "pending":
            qs = qs.filter(memberships__user=u, memberships__status="pending")
        elif f == "admin":
            qs = qs.filter(
                memberships__user=u,
                memberships__status="active",
                memberships__role__in=["executive", "president"],
            )

        if q:
            qs = qs.filter(Q(name__icontains=q) |
                           Q(tagline__icontains=q) |
                           Q(description__icontains=q))
        if cat:
            qs = qs.filter(category=cat)

        return qs.distinct().order_by("-members_count", "-created_at")

    def create(self, request, *args, **kwargs):
        ser = ClubCreateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        with transaction.atomic():
            club = ser.save(created_by=request.user)
            ClubMember.objects.create(
                club=club, user=request.user,
                status="active", role="president",
            )
            Club.objects.filter(pk=club.pk).update(members_count=1)
            club.refresh_from_db()
        out = ClubSerializer(club, context={"request": request})
        return Response(out.data, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────
# Detail
# ─────────────────────────────────────────────────────────────

class ClubDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET    /api/clubs/<pk>/
    PATCH  /api/clubs/<pk>/    admins only
    DELETE /api/clubs/<pk>/    president only — soft dissolve
    """
    permission_classes = [permissions.IsAuthenticated]
    queryset           = _active_qs()

    def get_serializer_class(self):
        return (ClubCreateSerializer
                if self.request.method in ("PUT", "PATCH")
                else ClubSerializer)

    def get_serializer_context(self):
        return {"request": self.request}

    def update(self, request, *args, **kwargs):
        club = self.get_object()
        if not _is_admin(club, request.user):
            return Response({"error": "Only club admins can edit."},
                            status=403)
        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        club = self.get_object()
        if not _is_president(club, request.user):
            return Response(
                {"error": "Only the president can dissolve this club."},
                status=403)
        reason = (request.data.get("reason", "").strip()
                  if request.data else "")
        club.is_active       = False
        club.dissolved_at    = timezone.now()
        club.dissolve_reason = reason or "Dissolved by president."
        club.save(update_fields=[
            "is_active", "dissolved_at", "dissolve_reason"])
        return Response({"success": True, "message": "Club dissolved."})


# ─────────────────────────────────────────────────────────────
# Join / Leave
#
# Join/leave responses return FLAT keys (is_member, is_pending, role,
# status) — that's what the frontend's _join() handler reads. The
# ClubSerializer above wraps them into a `membership` dict for
# list/detail responses; frontend handles both shapes.
# ─────────────────────────────────────────────────────────────

@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def join_club(request, pk):
    """POST /api/clubs/<pk>/join/"""
    try:
        club = _active_qs().get(pk=pk)
    except Club.DoesNotExist:
        return Response({"error": "Club not found."}, status=404)

    existing = _membership(club, request.user)
    if existing:
        return Response({
            "status":     existing.status,
            "role":       existing.role,
            "is_member":  existing.status == "active",
            "is_pending": existing.status == "pending",
            "is_admin":   _is_admin(club, request.user),
        })

    new_status = "pending" if club.requires_approval else "active"
    with transaction.atomic():
        ClubMember.objects.create(
            club=club, user=request.user,
            status=new_status, role="member",
        )
        if new_status == "active":
            Club.objects.filter(pk=club.pk).update(
                members_count=club.memberships.filter(
                    status="active").count())

    return Response({
        "status":     new_status,
        "role":       "member",
        "is_member":  new_status == "active",
        "is_pending": new_status == "pending",
        "is_admin":   False,
    })


@api_view(["DELETE"])
@permission_classes([permissions.IsAuthenticated])
def leave_club(request, pk):
    """DELETE /api/clubs/<pk>/leave/"""
    try:
        club = _active_qs().get(pk=pk)
    except Club.DoesNotExist:
        return Response({"error": "Club not found."}, status=404)

    m = _membership(club, request.user)
    if not m:
        return Response({"error": "You are not a member."}, status=400)
    if m.role == "president":
        return Response(
            {"error": "Transfer presidency before leaving the club."},
            status=400)

    with transaction.atomic():
        m.delete()
        Club.objects.filter(pk=club.pk).update(
            members_count=club.memberships.filter(status="active").count())
    return Response({"success": True})


# ─────────────────────────────────────────────────────────────
# Members
# ─────────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def club_members(request, pk):
    """GET /api/clubs/<pk>/members/?status=active|pending"""
    try:
        club = _active_qs().get(pk=pk)
    except Club.DoesNotExist:
        return Response({"error": "Club not found."}, status=404)

    s = request.query_params.get("status", "active")
    if s == "pending" and not _is_admin(club, request.user):
        return Response(
            {"error": "Only admins can view pending requests."}, status=403)

    qs = club.memberships.filter(status=s).select_related("user")
    role_order = {"president": 0, "executive": 1, "member": 2}
    rows = sorted(
        qs,
        key=lambda m: (role_order.get(m.role, 99),
                       (getattr(m.user, "display_name", "") or "").lower()),
    )
    ser = ClubMemberSerializer(rows, many=True, context={"request": request})
    return Response(ser.data)


def _resolve_member(club, user_id):
    """Find a ClubMember by the target user's public user_id string."""
    try:
        target = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        return None, Response({"error": "User not found."}, status=404)
    m = ClubMember.objects.filter(club=club, user=target).first()
    if not m:
        return None, Response(
            {"error": "User is not associated with this club."}, status=404)
    return m, None


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def approve_member(request, pk, user_id):
    """POST /api/clubs/<pk>/members/<user_id>/approve/  (admin only)"""
    try:
        club = _active_qs().get(pk=pk)
    except Club.DoesNotExist:
        return Response({"error": "Club not found."}, status=404)
    if not _is_admin(club, request.user):
        return Response({"error": "Admins only."}, status=403)

    m, err = _resolve_member(club, user_id)
    if err: return err
    if m.status != "pending":
        return Response({"error": "Not a pending request."}, status=400)

    with transaction.atomic():
        m.status = "active"
        m.save(update_fields=["status"])
        Club.objects.filter(pk=club.pk).update(
            members_count=club.memberships.filter(status="active").count())
    return Response({"success": True, "user_id": user_id})


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def reject_member(request, pk, user_id):
    """POST /api/clubs/<pk>/members/<user_id>/reject/  (admin only)"""
    try:
        club = _active_qs().get(pk=pk)
    except Club.DoesNotExist:
        return Response({"error": "Club not found."}, status=404)
    if not _is_admin(club, request.user):
        return Response({"error": "Admins only."}, status=403)

    m, err = _resolve_member(club, user_id)
    if err: return err
    if m.status != "pending":
        return Response({"error": "Not a pending request."}, status=400)
    m.delete()
    return Response({"success": True, "user_id": user_id})


@api_view(["DELETE"])
@permission_classes([permissions.IsAuthenticated])
def remove_member(request, pk, user_id):
    """DELETE /api/clubs/<pk>/members/<user_id>/  (admin only)"""
    try:
        club = _active_qs().get(pk=pk)
    except Club.DoesNotExist:
        return Response({"error": "Club not found."}, status=404)
    if not _is_admin(club, request.user):
        return Response({"error": "Admins only."}, status=403)

    m, err = _resolve_member(club, user_id)
    if err: return err
    if m.role == "president":
        return Response(
            {"error": "Cannot remove the president."}, status=400)
    if m.user_id == request.user.id:
        return Response(
            {"error": "Use the leave endpoint to remove yourself."},
            status=400)

    with transaction.atomic():
        m.delete()
        Club.objects.filter(pk=club.pk).update(
            members_count=club.memberships.filter(status="active").count())
    return Response({"success": True})


@api_view(["PATCH"])
@permission_classes([permissions.IsAuthenticated])
def change_member_role(request, pk, user_id):
    """
    PATCH /api/clubs/<pk>/members/<user_id>/role/
    body: {"role": "member"|"executive"|"president"}

    • Promoting to 'president' is allowed only if the caller is the
      current president; the existing president is demoted to
      'executive' in the same atomic transaction.
    • Promoting member→executive or demoting executive→member can be
      done by any active admin.
    """
    try:
        club = _active_qs().get(pk=pk)
    except Club.DoesNotExist:
        return Response({"error": "Club not found."}, status=404)

    new_role = (request.data.get("role") or "").strip().lower()
    if new_role not in {"member", "executive", "president"}:
        return Response(
            {"error": "role must be member / executive / president."},
            status=400)

    target, err = _resolve_member(club, user_id)
    if err: return err
    if target.status != "active":
        return Response(
            {"error": "Target is not an active member."}, status=400)

    if new_role == "president":
        if not _is_president(club, request.user):
            return Response(
                {"error": "Only the current president can transfer."},
                status=403)
        if target.user_id == request.user.id:
            return Response(
                {"error": "You are already the president."}, status=400)
        with transaction.atomic():
            ClubMember.objects.filter(
                club=club, user=request.user, status="active"
            ).update(role="executive")
            target.role = "president"
            target.save(update_fields=["role"])
        return Response(
            {"success": True, "user_id": user_id, "role": "president"})

    if not _is_admin(club, request.user):
        return Response({"error": "Admins only."}, status=403)
    if target.role == "president":
        return Response(
            {"error": "Cannot demote the president — transfer first."},
            status=400)

    target.role = new_role
    target.save(update_fields=["role"])
    return Response({"success": True, "user_id": user_id, "role": new_role})


# ─────────────────────────────────────────────────────────────
# Image uploads
# ─────────────────────────────────────────────────────────────

@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def upload_cover(request, pk):
    """POST /api/clubs/<pk>/cover/  (admin only)"""
    try:
        club = _active_qs().get(pk=pk)
    except Club.DoesNotExist:
        return Response({"error": "Club not found."}, status=404)
    if not _is_admin(club, request.user):
        return Response({"error": "Admins only."}, status=403)
    f = request.FILES.get("cover") or request.FILES.get("file")
    if not f:
        return Response({"error": "No file provided."}, status=400)
    club.cover = f
    club.save(update_fields=["cover"])
    out = ClubSerializer(club, context={"request": request})
    return Response(out.data)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def upload_logo(request, pk):
    """POST /api/clubs/<pk>/logo/  (admin only)"""
    try:
        club = _active_qs().get(pk=pk)
    except Club.DoesNotExist:
        return Response({"error": "Club not found."}, status=404)
    if not _is_admin(club, request.user):
        return Response({"error": "Admins only."}, status=403)
    f = request.FILES.get("logo") or request.FILES.get("file")
    if not f:
        return Response({"error": "No file provided."}, status=400)
    club.logo = f
    club.save(update_fields=["logo"])
    out = ClubSerializer(club, context={"request": request})
    return Response(out.data)