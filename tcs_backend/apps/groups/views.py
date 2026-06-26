from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import generics, serializers, status
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response

from apps.chat.models import SavedMaterial          # ← for the new save-to-library endpoint
from .models import Group, GroupMember, GroupMaterial

User = get_user_model()


# ── Serializers ───────────────────────────────────────────────

class GroupSerializer(serializers.ModelSerializer):
    avatar_url      = serializers.SerializerMethodField()
    is_joined       = serializers.SerializerMethodField()
    is_creator      = serializers.SerializerMethodField()
    is_admin        = serializers.SerializerMethodField()
    is_expired      = serializers.SerializerMethodField()
    # ── exposed from new model properties ──────────────────
    display_subject = serializers.ReadOnlyField()
    display_emoji   = serializers.ReadOnlyField()

    class Meta:
        model  = Group
        fields = [
            "id", "name", "description", "purpose", "category", "theme",
            "theme_icon", "display_emoji", "subject", "display_subject",
            "avatar_url", "is_public", "is_academic",
            "requires_approval", "members_count", "active_now",
            "duration_days", "expires_at", "is_joined", "is_admin",
            "is_expired", "created_at",
            "is_creator",
        ]

    def get_avatar_url(self, obj):
        req = self.context.get("request")
        if obj.avatar:
            return req.build_absolute_uri(obj.avatar.url) if req else obj.avatar.url
        return None

    def get_is_creator(self, obj):
        req = self.context.get('request')
        return bool(req and req.user.is_authenticated
                    and obj.created_by_id == req.user.id)

    def get_is_joined(self, obj):
        u = self.context.get("request") and self.context["request"].user
        return bool(u) and GroupMember.objects.filter(group=obj, user=u, status="active").exists()

    def get_is_admin(self, obj):
        u = self.context.get("request") and self.context["request"].user
        return bool(u) and (obj.created_by == u or obj.admins.filter(id=u.id).exists())

    def get_is_expired(self, obj):
        # Delegate to the model property so this logic lives in one place.
        return obj.is_expired


class GroupMemberSerializer(serializers.ModelSerializer):
    user_id    = serializers.CharField(source="user.user_id")
    name       = serializers.CharField(source="user.display_name")
    role       = serializers.CharField(source="user.role")
    avatar_url = serializers.SerializerMethodField()
    is_admin   = serializers.SerializerMethodField()
    is_mentor  = serializers.SerializerMethodField()

    class Meta:
        model  = GroupMember
        fields = ["user_id", "name", "role", "avatar_url", "status", "joined_at",
                  "is_admin", "is_mentor"]

    def get_avatar_url(self, obj):
        req = self.context.get("request")
        if obj.user.avatar:
            return req.build_absolute_uri(obj.user.avatar.url) if req else obj.user.avatar.url
        return None

    def get_is_admin(self, obj):
        return obj.group.admins.filter(id=obj.user.id).exists() or obj.group.created_by == obj.user

    def get_is_mentor(self, obj):
        return obj.membership_role == GroupMember.Role.MENTOR


class GroupMaterialSerializer(serializers.ModelSerializer):
    uploaded_by_name = serializers.CharField(source="uploaded_by.display_name", read_only=True)
    file_url         = serializers.SerializerMethodField()
    # ── from model property — frontend uses this to show "Quiz me" ──
    is_quizable      = serializers.ReadOnlyField()
    # ── group context — handy when listing materials cross-group ────
    group_id         = serializers.CharField(read_only=True)
    group_name       = serializers.CharField(source="group.name", read_only=True)

    class Meta:
        model  = GroupMaterial
        fields = ["id", "title", "file_url", "file_name", "file_type",
                  "file_size", "uploaded_by_name", "created_at",
                  "is_quizable", "group_id", "group_name"]

    def get_file_url(self, obj):
        req = self.context.get("request")
        if obj.file:
            return req.build_absolute_uri(obj.file.url) if req else obj.file.url
        return None


class StudyBuddySerializer(serializers.ModelSerializer):
    """Simple user card for the study buddy list."""
    user_id    = serializers.CharField(source="user_id")
    name       = serializers.CharField(source="display_name")
    role       = serializers.CharField()
    avatar_url = serializers.SerializerMethodField()
    subjects   = serializers.CharField(source="study_subjects")

    class Meta:
        model  = User
        fields = ["user_id", "name", "role", "avatar_url", "subjects",
                  "is_available_study", "study_subjects", "is_online"]

    def get_avatar_url(self, obj):
        req = self.context.get("request")
        if obj.avatar:
            return req.build_absolute_uri(obj.avatar.url) if req else obj.avatar.url
        return None


# ── Group CRUD ────────────────────────────────────────────────

class GroupListCreateView(generics.ListCreateAPIView):
    serializer_class = GroupSerializer

    def get_queryset(self):
        user   = self.request.user
        f      = self.request.query_params.get("filter", "all")
        q      = self.request.query_params.get("q", "")
        theme  = self.request.query_params.get("theme", "")
        cat    = self.request.query_params.get("category", "")

        if f == "mine":
            qs = Group.objects.filter(members=user, is_active=True)
        elif f == "suggested":
            joined_ids = user.study_groups.values_list("id", flat=True)
            qs = Group.objects.filter(is_public=True, is_active=True).exclude(id__in=joined_ids)
        else:
            qs = Group.objects.filter(is_public=True, is_active=True)

        if q:
            qs = qs.filter(Q(name__icontains=q) | Q(description__icontains=q))
        if theme:
            qs = qs.filter(theme=theme)
        if cat:
            qs = qs.filter(category=cat)

        return qs.exclude(expires_at__lt=timezone.now()).order_by("-members_count")

    def perform_create(self, serializer):
        with transaction.atomic():
            group = serializer.save(created_by=self.request.user)
            group.admins.add(self.request.user)
            GroupMember.objects.create(group=group, user=self.request.user, status="active")
            Group.objects.filter(pk=group.pk).update(members_count=1)

            # Add initial members if private
            member_ids = self.request.data.get("initial_member_ids", [])
            for uid in member_ids:
                try:
                    u = User.objects.get(user_id=uid)
                    if u != self.request.user:
                        GroupMember.objects.get_or_create(group=group, user=u,
                                                          defaults={"status": "active"})
                        Group.objects.filter(pk=group.pk).update(
                            members_count=group.memberships.filter(status="active").count())
                except User.DoesNotExist:
                    pass


class GroupDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = GroupSerializer
    queryset         = Group.objects.filter(is_active=True)

    def destroy(self, request, *args, **kwargs):
        group = self.get_object()
        if group.created_by != request.user and not group.admins.filter(id=request.user.id).exists():
            return Response({"error": "Only admins can dissolve this group."}, status=403)
        reason = request.data.get("reason", "").strip()
        if not reason:
            return Response({"error": "Please provide a reason for dissolving the group."}, status=400)
        group.is_active      = False
        group.dissolved_at   = timezone.now()
        group.dissolve_reason = reason
        group._dissolved_by = request.user
        group.save(update_fields=["is_active", "dissolved_at", "dissolve_reason"])
        return Response({"success": True, "message": "Group dissolved."})


@api_view(["GET"])
def group_members(request, group_id):
    try:
        group = Group.objects.get(id=group_id)
    except Group.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    members = group.memberships.filter(status="active").select_related("user")
    return Response(GroupMemberSerializer(members, many=True, context={"request": request}).data)


@api_view(["POST"])
def add_group_member(request, group_id):
    """Admin-only: add a member."""
    try:
        group = Group.objects.get(id=group_id, is_active=True)
    except Group.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    if not (group.created_by == request.user or group.admins.filter(id=request.user.id).exists()):
        return Response({"error": "Only admins can add members."}, status=403)
    uid = request.data.get("user_id", "")
    try:
        user = User.objects.get(user_id=uid)
    except User.DoesNotExist:
        return Response({"error": "User not found."}, status=404)
    _, created = GroupMember.objects.get_or_create(group=group, user=user,
                                                   defaults={"status": "active"})
    if created:
        Group.objects.filter(pk=group.pk).update(
            members_count=group.memberships.filter(status="active").count())
        try:
            # tcs-notify:group-add
            from apps.notifications.tasks import push_group_add_notification
            push_group_add_notification.delay(
                str(user.id), str(request.user.id), group.name,
                "group", str(group.id))
        except Exception:
            pass
    return Response({"success": True})


@api_view(["POST"])
def remove_group_member(request, group_id):
    """Admin-only: remove a member."""
    try:
        group = Group.objects.get(id=group_id, is_active=True)
    except Group.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    if not (group.created_by == request.user or group.admins.filter(id=request.user.id).exists()):
        return Response({"error": "Only admins can remove members."}, status=403)
    uid = request.data.get("user_id", "")
    GroupMember.objects.filter(group=group, user__user_id=uid).delete()
    Group.objects.filter(pk=group.pk).update(
        members_count=group.memberships.filter(status="active").count())
    return Response({"success": True})


@api_view(["POST"])
def join_group(request, group_id):
    try:
        group = Group.objects.get(id=group_id, is_active=True)
    except Group.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    if not group.is_public:
        return Response({"error": "This group is private."}, status=403)
    m_status = "pending" if group.requires_approval else "active"
    _, created = GroupMember.objects.get_or_create(
        group=group, user=request.user, defaults={"status": m_status})
    if created and m_status == "active":
        Group.objects.filter(pk=group.pk).update(members_count=group.members_count + 1)
    return Response({"status": m_status})


@api_view(["DELETE"])
def leave_group(request, group_id):
    try:
        group = Group.objects.get(id=group_id)
    except Group.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    if group.created_by == request.user:
        return Response({"error": "Creator cannot leave — dissolve the group instead."}, status=400)
    GroupMember.objects.filter(group=group, user=request.user).delete()
    Group.objects.filter(pk=group.pk).update(
        members_count=max(0, group.members_count - 1))
    return Response({"success": True})


_TEACHER_ROLES = ("teaching_staff", "admin")


def _is_teacher(user):
    return bool(getattr(user, "is_superuser", False)) or \
        (getattr(user, "role", "") or "").lower() in _TEACHER_ROLES


@api_view(["POST"])
def join_group_as_mentor(request, group_id):
    """A teacher joins a study group as a visible mentor (spec §3G). A teacher
    in a student study space is a supervised, educational context — so a mentor
    joins active immediately, bypassing approval. Toggling off steps back down
    to a normal membership rather than leaving entirely."""
    if not _is_teacher(request.user):
        return Response({"error": "Only teachers can join as a mentor."}, status=403)
    try:
        group = Group.objects.get(id=group_id, is_active=True)
    except Group.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    m = GroupMember.objects.filter(group=group, user=request.user).first()
    created = False
    if m is None:
        m = GroupMember.objects.create(
            group=group, user=request.user, status="active",
            membership_role=GroupMember.Role.MENTOR)
        created = True
    else:
        m.membership_role = GroupMember.Role.MENTOR
        m.status = "active"
        m.save(update_fields=["membership_role", "status"])
    if created:
        Group.objects.filter(pk=group.pk).update(members_count=group.members_count + 1)
    return Response({"is_mentor": True, "status": "active"})


@api_view(["POST"])
def step_down_mentor(request, group_id):
    """A mentor steps back down to an ordinary membership (keeps their seat)."""
    m = GroupMember.objects.filter(group=group_id, user=request.user).first()
    if m is None:
        return Response({"error": "You are not in this group."}, status=404)
    m.membership_role = GroupMember.Role.MEMBER
    m.save(update_fields=["membership_role"])
    return Response({"is_mentor": False})


@api_view(["GET", "POST"])
@parser_classes([MultiPartParser, FormParser])
def group_materials(request, group_id):
    try:
        group = Group.objects.get(id=group_id, is_active=True)
    except Group.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    if not GroupMember.objects.filter(group=group, user=request.user, status="active").exists():
        return Response({"error": "Must be a member."}, status=403)

    if request.method == "GET":
        materials = group.materials.select_related("uploaded_by", "group")
        return Response(GroupMaterialSerializer(materials, many=True,
                                                context={"request": request}).data)

    # POST — upload material
    file  = request.FILES.get("file")
    title = request.data.get("title", "")
    if not file:
        return Response({"error": "file required."}, status=400)
    mat = GroupMaterial.objects.create(
        group=group, uploaded_by=request.user, title=title or file.name,
        file=file, file_name=file.name, file_size=file.size,
        file_type=file.content_type or "",
    )
    return Response(GroupMaterialSerializer(mat, context={"request": request}).data,
                    status=status.HTTP_201_CREATED)


# ── NEW: Save a group material into the user's personal library ───
#
# This is what closes the gap for the quiz feature: a user browsing a
# study group can tap "Save to my library" on any material, and it
# lands in their SavedMaterial list with subject + source_group already
# tagged — so it shows up correctly in the By-Subject / By-Group views
# and is immediately available for AI quiz generation.

@api_view(["POST"])
def save_group_material(request, group_id, material_id):
    """
    POST /api/groups/<group_id>/materials/<material_id>/save/

    Body (all optional):
      { "title": "...", "subject": "..." }   — overrides the auto-derived values.

    Returns the new SavedMaterial (chat app's serializer would normally
    render this, but we return a minimal payload to avoid a cross-app
    serializer import).
    """
    try:
        group = Group.objects.get(id=group_id, is_active=True)
    except Group.DoesNotExist:
        return Response({"error": "Group not found."}, status=404)

    if not GroupMember.objects.filter(
            group=group, user=request.user, status="active").exists():
        return Response({"error": "You must be a member of this group."}, status=403)

    try:
        material = GroupMaterial.objects.get(id=material_id, group=group)
    except GroupMaterial.DoesNotExist:
        return Response({"error": "Material not found in this group."}, status=404)

    if not material.file:
        return Response({"error": "This material has no associated file."}, status=400)

    # Build an absolute URL so SavedMaterial can fetch it later for the
    # quiz generator. With Cloudinary this is already a full https:// URL.
    file_url = (request.build_absolute_uri(material.file.url)
                if request else material.file.url)

    title   = (request.data.get("title")   or material.title or material.file_name).strip()
    subject = (request.data.get("subject") or group.display_subject).strip()

    saved = SavedMaterial.objects.create(
        user=request.user,
        message=None,
        title=title,
        file_url=file_url,
        file_name=material.file_name or "",
        file_type=material.file_type or "",
        subject=subject,
        source_type="group",
        source_group=group,
        source_name=group.name,
    )

    return Response({
        "id":                 str(saved.id),
        "title":              saved.title,
        "file_url":           saved.file_url,
        "file_name":          saved.file_name,
        "file_type":          saved.file_type,
        "subject":            saved.subject,
        "source_type":        saved.source_type,
        "source_group_id":    str(saved.source_group_id) if saved.source_group_id else None,
        "source_group_name":  saved.source_name,
        "created_at":         saved.created_at.isoformat(),
    }, status=status.HTTP_201_CREATED)


# ── Study Buddy ───────────────────────────────────────────────

@api_view(["GET"])
def study_buddies(request):
    """GET /api/groups/buddies/?subject=... — available study buddies."""
    subject = request.query_params.get("subject", "").strip()
    qs = User.objects.filter(is_available_study=True).exclude(id=request.user.id)
    if subject:
        qs = qs.filter(study_subjects__icontains=subject)
    data = []
    for u in qs[:50]:
        data.append({
            "user_id":    u.user_id,
            "name":       u.display_name,
            "role":       u.role,
            "avatar_url": request.build_absolute_uri(u.avatar.url) if u.avatar else None,
            "subjects":   u.study_subjects,
            "is_online":  u.is_online,
        })
    return Response(data)


@api_view(["POST"])
def update_study_buddy(request):
    """POST /api/groups/buddies/me/ — { available: bool, subjects: "Math, Physics" }"""
    available = request.data.get("available", False)
    subjects  = request.data.get("subjects", "")
    request.user.is_available_study = available
    request.user.study_subjects     = subjects
    request.user.save(update_fields=["is_available_study", "study_subjects"])
    return Response({
        "available": available,
        "subjects":  subjects,
    })


@api_view(["GET"])
def search_users_for_group(request):
    """GET /api/groups/user-search/?q=... — search platform users to add to group."""
    q = request.query_params.get("q", "").strip()
    if len(q) < 1:
        return Response({"results": []})
    users = User.objects.filter(
        Q(name__icontains=q) | Q(preferred_name__icontains=q) | Q(user_id__icontains=q)
    ).exclude(id=request.user.id)[:20]
    return Response({"results": [
        {
            "user_id":  u.user_id,
            "name":     u.display_name,
            "role":     u.role,
            "avatar_url": request.build_absolute_uri(u.avatar.url) if u.avatar else None,
        }
        for u in users
    ]})

# ─────────────────────────────────────────────────────────────
# Dale AI in study groups — mirrors /chat/rooms/<id>/ai/summon/
# ─────────────────────────────────────────────────────────────
import logging as _logging
_logger = _logging.getLogger(__name__)


@api_view(["POST"])
def summon_dale_in_group_view(request, group_id):
    """POST /api/groups/<id>/ai/summon/  — body: {"message": "..."} (optional).

    Summons Dale to read the recent group chat and reply as an is_ai Post,
    visible to everyone in the group. Same mechanism as the chat-room summon.
    """
    try:
        group = Group.objects.get(id=group_id, is_active=True)
    except Group.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    is_member = group.memberships.filter(
        user=request.user, status="active").exists()
    if not (is_member or group.created_by == request.user):
        return Response({"error": "Join the group to chat with Dale."}, status=403)

    user_msg = (request.data.get("message") or "").strip()
    try:
        from .ai_in_group import summon_dale_in_group, AIError
        post = summon_dale_in_group(
            group, request.user, asker_message=user_msg or None)
    except AIError as e:
        return Response({"error": str(e)}, status=503)
    except Exception:
        _logger.exception("summon_dale_in_group failed")
        return Response({"error": "Dale couldn't reply right now."}, status=500)

    from apps.posts.serializers import PostSerializer
    return Response(
        PostSerializer(post, context={"request": request}).data, status=201)
