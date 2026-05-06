from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import generics, serializers, status
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from .models import Group, GroupMember, GroupMaterial

User = get_user_model()


# ── Serializers ───────────────────────────────────────────────

class GroupSerializer(serializers.ModelSerializer):
    avatar_url  = serializers.SerializerMethodField()
    is_joined   = serializers.SerializerMethodField()
    is_admin    = serializers.SerializerMethodField()
    is_expired  = serializers.SerializerMethodField()

    class Meta:
        model  = Group
        fields = [
            "id", "name", "description", "purpose", "category", "theme",
            "theme_icon", "subject", "avatar_url", "is_public", "is_academic",
            "requires_approval", "members_count", "active_now",
            "duration_days", "expires_at", "is_joined", "is_admin",
            "is_expired", "created_at",
        ]

    def get_avatar_url(self, obj):
        req = self.context.get("request")
        if obj.avatar:
            return req.build_absolute_uri(obj.avatar.url) if req else obj.avatar.url
        return None

    def get_is_joined(self, obj):
        u = self.context.get("request") and self.context["request"].user
        return bool(u) and GroupMember.objects.filter(group=obj, user=u, status="active").exists()

    def get_is_admin(self, obj):
        u = self.context.get("request") and self.context["request"].user
        return bool(u) and (obj.created_by == u or obj.admins.filter(id=u.id).exists())

    def get_is_expired(self, obj):
        if obj.expires_at:
            return timezone.now() > obj.expires_at
        return False


class GroupMemberSerializer(serializers.ModelSerializer):
    user_id    = serializers.CharField(source="user.user_id")
    name       = serializers.CharField(source="user.display_name")
    role       = serializers.CharField(source="user.role")
    avatar_url = serializers.SerializerMethodField()
    is_admin   = serializers.SerializerMethodField()

    class Meta:
        model  = GroupMember
        fields = ["user_id", "name", "role", "avatar_url", "status", "joined_at", "is_admin"]

    def get_avatar_url(self, obj):
        req = self.context.get("request")
        if obj.user.avatar:
            return req.build_absolute_uri(obj.user.avatar.url) if req else obj.user.avatar.url
        return None

    def get_is_admin(self, obj):
        return obj.group.admins.filter(id=obj.user.id).exists() or obj.group.created_by == obj.user


class GroupMaterialSerializer(serializers.ModelSerializer):
    uploaded_by_name = serializers.CharField(source="uploaded_by.display_name", read_only=True)
    file_url         = serializers.SerializerMethodField()

    class Meta:
        model  = GroupMaterial
        fields = ["id", "title", "file_url", "file_name", "file_type",
                  "file_size", "uploaded_by_name", "created_at"]

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
        materials = group.materials.select_related("uploaded_by")
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