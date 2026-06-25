# apps/notifications/announcement_views.py
from django.db.models import Q, F
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.accounts.permissions import IsStaff, IsElevatedStaff
from .models import Announcement


def _b(v, default=False):
    if isinstance(v, bool):
        return v
    if v is None:
        return default
    return str(v).strip().lower() in ("1", "true", "yes", "on")


def _is_staff(u):
    role = (getattr(u, "role", "") or "").lower()
    return u.is_superuser or role in ("teaching_staff", "non_teaching_staff", "admin")


def _can_edit(u, a):
    role = (getattr(u, "role", "") or "").lower()
    return u.is_superuser or role in ("teaching_staff", "admin") or a.author_id == u.id


class AnnouncementSerializer(serializers.ModelSerializer):
    author_name    = serializers.CharField(source="author.display_name", read_only=True, allow_null=True)
    author_role    = serializers.CharField(source="author.role", read_only=True, allow_null=True)
    category_label = serializers.CharField(source="get_category_display", read_only=True)
    image_url      = serializers.SerializerMethodField()

    class Meta:
        model  = Announcement
        fields = ["id", "title", "body", "category", "category_label",
                  "audience", "year_group", "accent", "image_url",
                  "is_pinned", "is_published", "view_count",
                  "author_name", "author_role", "created_at"]

    def get_image_url(self, obj):
        if not obj.image:
            return None
        try:
            url = obj.image.url
        except Exception:
            return None
        req = self.context.get("request")
        return req.build_absolute_uri(url) if req else url


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def announcement_list(request):
    u   = request.user
    now = timezone.now()
    qs  = Announcement.objects.select_related("author")

    if not _is_staff(u):
        qs = qs.filter(is_published=True)
        qs = qs.filter(Q(publish_at__isnull=True) | Q(publish_at__lte=now))
        qs = qs.filter(Q(expires_at__isnull=True) | Q(expires_at__gte=now))
        aud = Q(audience="all") | Q(audience="students")
        yg  = (getattr(u, "year_group", "") or "").strip()
        if yg:
            aud |= Q(audience="year_group", year_group=yg)
        qs = qs.filter(aud)

    qs   = qs.order_by("-is_pinned", "-created_at")[:200]
    data = AnnouncementSerializer(qs, many=True, context={"request": request}).data
    return Response(data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def announcement_detail(request, pk):
    a = Announcement.objects.select_related("author").filter(id=pk).first()
    if not a:
        return Response({"error": "Not found."}, status=404)
    Announcement.objects.filter(id=pk).update(view_count=F("view_count") + 1)
    a.view_count += 1
    return Response(AnnouncementSerializer(a, context={"request": request}).data)


@api_view(["POST"])
@permission_classes([IsStaff])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def announcement_create(request):
    d     = request.data
    title = (d.get("title") or "").strip()
    body  = (d.get("body") or "").strip()
    if not title or not body:
        return Response({"error": "Title and body are required."}, status=400)

    a = Announcement(
        author       = request.user,
        title        = title[:200],
        body         = body,
        category     = (d.get("category") or "general").strip(),
        audience     = (d.get("audience") or "all").strip(),
        year_group   = (d.get("year_group") or "").strip(),
        accent       = (d.get("accent") or "").strip(),
        is_pinned    = _b(d.get("is_pinned")),
        is_published = _b(d.get("is_published"), True),
    )
    img = request.FILES.get("image")
    if img:
        a.image = img
    a.save()

    if a.is_published and (a.publish_at is None or a.publish_at <= timezone.now()):
        try:
            from .announcement_tasks import push_announcement
            push_announcement.delay(str(a.id))
        except Exception:
            pass

    return Response(AnnouncementSerializer(a, context={"request": request}).data,
                    status=status.HTTP_201_CREATED)


@api_view(["PATCH"])
@permission_classes([IsStaff])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def announcement_update(request, pk):
    a = Announcement.objects.filter(id=pk).first()
    if not a:
        return Response({"error": "Not found."}, status=404)
    if not _can_edit(request.user, a):
        return Response({"error": "You cannot edit this announcement."}, status=403)

    d = request.data
    for f in ("title", "body", "category", "audience", "year_group", "accent"):
        if f in d and d.get(f) is not None:
            setattr(a, f, str(d.get(f)).strip())
    if "is_pinned" in d:
        a.is_pinned = _b(d.get("is_pinned"))
    if "is_published" in d:
        a.is_published = _b(d.get("is_published"), True)
    img = request.FILES.get("image")
    if img:
        a.image = img
    a.save()
    return Response(AnnouncementSerializer(a, context={"request": request}).data)


@api_view(["DELETE"])
@permission_classes([IsStaff])
def announcement_delete(request, pk):
    a = Announcement.objects.filter(id=pk).first()
    if not a:
        return Response({"error": "Not found."}, status=404)
    if not _can_edit(request.user, a):
        return Response({"error": "You cannot delete this announcement."}, status=403)
    a.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
@permission_classes([IsElevatedStaff])
def announcement_pin(request, pk):
    a = Announcement.objects.filter(id=pk).first()
    if not a:
        return Response({"error": "Not found."}, status=404)
    a.is_pinned = not a.is_pinned
    a.save(update_fields=["is_pinned"])
    return Response({"id": str(a.id), "is_pinned": a.is_pinned})
