# apps/events/views.py
from django.db import transaction
from django.db.models import Q
from rest_framework import generics, serializers, status, filters
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Event, EventRSVP


TEACHER_ROLES = {"teaching_staff", "admin"}

# Match the per-image cap used by posts (apps/posts settings).
_MAX_POSTER_BYTES = 8 * 1024 * 1024  # 8 MB
_ALLOWED_POSTER_TYPES = {
    "image/jpeg", "image/jpg", "image/png", "image/webp", "image/gif",
}


def _is_teacher(user):
    return user.role in TEACHER_ROLES


# ─────────────────────────────────────────────────────────────
# Serializer
# ─────────────────────────────────────────────────────────────

class EventSerializer(serializers.ModelSerializer):
    organizer_name = serializers.CharField(
        source="organizer.display_name", read_only=True)
    organizer_role = serializers.CharField(
        source="organizer.role", read_only=True)

    # Writable poster upload — required on create (see validate()).
    image = serializers.ImageField(write_only=True, required=False,
                                   allow_null=False)
    # External / AI-generated poster URL (alternative to an uploaded file).
    poster_url = serializers.URLField(required=False, allow_blank=True)

    image_url   = serializers.SerializerMethodField()
    is_rsvped   = serializers.SerializerMethodField()
    is_full     = serializers.BooleanField(read_only=True)
    can_manage  = serializers.SerializerMethodField()

    class Meta:
        model  = Event
        fields = [
            "id", "title", "description", "category", "audience",
            "organizer_name", "organizer_role",
            "image",            # write
            "poster_url",       # write/read (external/AI poster)
            "image_url",        # read
            "location",
            "club",  # tcs-club-field
            "is_online", "meeting_url", "start_time", "end_time",
            "max_attendees", "attendees_count", "is_featured",
            "is_full", "is_rsvped", "can_manage", "created_at",
            "club",]
        read_only_fields = ["id", "attendees_count", "created_at"]

    # ── Validators ────────────────────────────────────────────

    def validate_image(self, file):
        """Size and MIME type guard for uploaded posters."""
        if file is None:
            return file
        # Size
        size = getattr(file, "size", None)
        if size is not None and size > _MAX_POSTER_BYTES:
            mb = size / (1024 * 1024)
            raise serializers.ValidationError(
                f"Poster is {mb:.1f} MB — please keep it under 8 MB.")
        # MIME
        ctype = (getattr(file, "content_type", "") or "").lower()
        if ctype and ctype not in _ALLOWED_POSTER_TYPES:
            raise serializers.ValidationError(
                "Poster must be a JPG, PNG, WebP, or GIF image.")
        return file

    def validate(self, attrs):
        """
        Poster is required when CREATING an event (instance is None).
        Updates can omit the image field — they keep the existing poster.
        """
        is_create = self.instance is None
        # When creating, need either an uploaded `image` OR an AI/external
        # poster_url.
        if is_create and not attrs.get("image") and not attrs.get("poster_url"):
            raise serializers.ValidationError({
                "image": "A poster is required when creating an event.",
            })
        return attrs

    # ── Computed read fields ──────────────────────────────────

    def get_image_url(self, obj):
        req = self.context.get("request")
        if obj.image:
            try:
                return req.build_absolute_uri(obj.image.url) if req else obj.image.url
            except Exception:
                pass
        return obj.poster_url or None

    def get_is_rsvped(self, obj):
        req = self.context.get("request")
        if req and req.user.is_authenticated:
            return EventRSVP.objects.filter(event=obj, user=req.user).exists()
        return False

    def get_can_manage(self, obj):
        req = self.context.get("request")
        if not req or not req.user.is_authenticated:
            return False
        return obj.organizer == req.user or _is_teacher(req.user)


# ─────────────────────────────────────────────────────────────
# List + Create
# ─────────────────────────────────────────────────────────────

class EventListCreateView(generics.ListCreateAPIView):
    serializer_class = EventSerializer
    # Accept both JSON (list page filtering) and multipart (create with poster).
    parser_classes   = [MultiPartParser, FormParser, JSONParser]
    filter_backends  = [filters.SearchFilter, filters.OrderingFilter]
    search_fields    = ["title", "description", "location"]
    ordering_fields  = ["start_time", "attendees_count", "created_at"]
    ordering         = ["start_time"]

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        qs = (Event.objects
                   .filter(is_active=True)
                   .filter(Q(club__isnull=True) | Q(club__is_active=True))
                   .select_related("organizer"))
        category = self.request.query_params.get("category")
        featured = self.request.query_params.get("featured")
        if category:
            qs = qs.filter(category=category)
        if featured:
            qs = qs.filter(is_featured=True)
        return qs

    def perform_create(self, serializer):
        # Only teaching staff and admins can create events
        if not _is_teacher(self.request.user):
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Only teaching staff can create events.")
        event = serializer.save(organizer=self.request.user)
        _notify_event_audience(event, self.request.user)


def _notify_event_audience(event, actor):
    """Fan an event out to its audience as in-app + FCM notifications. Tapping
    the notification (target_type=event) opens the event detail."""
    try:
        from django.contrib.auth import get_user_model
        from apps.notifications.tasks import _create, _fcm_send_multi
        User = get_user_model()
        qs = User.objects.filter(is_active=True)
        aud = getattr(event, "audience", "everyone")
        if aud == "students":
            qs = qs.filter(role="student")
        elif aud == "staff":
            qs = qs.filter(role__in=["teaching_staff", "non_teaching_staff", "admin"])
        qs = qs.exclude(id=actor.id)
        title = "📅 New event"
        body = event.title
        toks = []
        for u in qs.iterator():
            try:
                _create(str(u.id), str(actor.id), "event", title, body,
                        "event", str(event.id))
                t = getattr(u, "fcm_token", None)
                if t:
                    toks.append(t)
            except Exception:
                pass
        _fcm_send_multi(toks, title, body,
                        {"type": "event", "event_id": str(event.id)})
    except Exception:
        import logging
        logging.getLogger(__name__).exception("event notify failed")


# ─────────────────────────────────────────────────────────────
# Detail
# ─────────────────────────────────────────────────────────────

class EventDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = EventSerializer
    queryset         = (Event.objects
                            .filter(is_active=True)
                            .filter(Q(club__isnull=True) | Q(club__is_active=True)))
    parser_classes   = [MultiPartParser, FormParser, JSONParser]

    def get_serializer_context(self):
        return {"request": self.request}

    def update(self, request, *args, **kwargs):
        event = self.get_object()
        if not (event.organizer == request.user or _is_teacher(request.user)):
            return Response({"error": "Permission denied."}, status=403)
        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        event = self.get_object()
        # Any staff member (incl. non-teaching) — or the organizer — may remove.
        is_staff = (getattr(request.user, "role", "") in
                    ("teaching_staff", "non_teaching_staff", "admin")) or \
            bool(getattr(request.user, "is_superuser", False))
        if not (event.organizer == request.user or is_staff):
            return Response({"error": "Permission denied."}, status=403)
        event.is_active = False
        event.save(update_fields=["is_active"])
        return Response(status=status.HTTP_204_NO_CONTENT)


# ─────────────────────────────────────────────────────────────
# RSVP toggle
# ─────────────────────────────────────────────────────────────

@api_view(["POST"])
def rsvp_toggle(request, event_id):
    try:
        event = Event.objects.get(id=event_id, is_active=True)
    except Event.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    with transaction.atomic():
        rsvp, created = EventRSVP.objects.get_or_create(
            event=event, user=request.user)
        if not created:
            rsvp.delete()
            Event.objects.filter(pk=event.pk).update(
                attendees_count=max(0, event.attendees_count - 1))
            action = "cancelled"
        else:
            if event.is_full:
                rsvp.delete()
                return Response({"error": "Event is full."}, status=400)
            Event.objects.filter(pk=event.pk).update(
                attendees_count=event.attendees_count + 1)
            action = "confirmed"

    event.refresh_from_db()
    return Response({"action": action,
                     "attendees_count": event.attendees_count})


# ─────────────────────────────────────────────────────────────
# Mine / managed
# ─────────────────────────────────────────────────────────────

@api_view(["GET"])
def my_events(request):
    events = Event.objects.filter(rsvps__user=request.user, is_active=True)
    return Response(EventSerializer(
        events, many=True, context={"request": request}).data)


@api_view(["GET"])
def teacher_events(request):
    """GET /api/events/managed/ — events created by the current teacher."""
    if not _is_teacher(request.user):
        return Response({"error": "Permission denied."}, status=403)
    events = Event.objects.filter(organizer=request.user, is_active=True)
    return Response(EventSerializer(
        events, many=True, context={"request": request}).data)

# ─────────────────────────────────────────────────────────────
# Phase 2 spec 9.4 — 3-state RSVP setter
# Wired by apps/events/urls.py:
#   path("<uuid:event_id>/rsvp/", views.rsvp_set, ...)
# Body: {"status": "going" | "interested" | "not_going" | "clear"}
# ─────────────────────────────────────────────────────────────
@api_view(["POST"])
def rsvp_set(request, event_id):
    try:
        event = Event.objects.get(id=event_id, is_active=True)
    except Event.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    new_status = (request.data.get("status") or "").strip().lower()
    if new_status not in ("going", "interested", "not_going", "clear"):
        return Response({"error": "status must be going/interested/not_going/clear."},
                        status=400)

    with transaction.atomic():
        existing  = EventRSVP.objects.filter(event=event, user=request.user).first()
        was_going = bool(existing and existing.status == EventRSVP.Status.GOING)

        if new_status == "clear":
            if existing:
                existing.delete()
            now_going = False
        else:
            if new_status == "going" and not was_going and event.is_full:
                return Response({"error": "Event is full."}, status=400)
            if existing:
                existing.status = new_status
                existing.save(update_fields=["status", "updated_at"])
            else:
                EventRSVP.objects.create(
                    event=event, user=request.user, status=new_status)
            now_going = (new_status == "going")

        # attendees_count tracks the GOING count only.
        if was_going and not now_going:
            Event.objects.filter(pk=event.pk).update(
                attendees_count=max(0, event.attendees_count - 1))
        elif not was_going and now_going:
            Event.objects.filter(pk=event.pk).update(
                attendees_count=event.attendees_count + 1)

    event.refresh_from_db()
    new_rsvp = EventRSVP.objects.filter(event=event, user=request.user).first()
    return Response({
        "rsvp_status":      new_rsvp.status if new_rsvp else None,
        "going_count":      event.attendees_count,
        "interested_count": event.rsvps.filter(
                              status=EventRSVP.Status.INTERESTED).count(),
        "is_full":          event.is_full,
    })


# ─────────────────────────────────────────────────────────────
# Phase 2 spec 10.2 — event poster upload (Cloudinary)
# Wired by apps/events/urls.py:
#   path("<uuid:event_id>/poster/", views.upload_event_poster, ...)
# ─────────────────────────────────────────────────────────────
@api_view(["POST"])
@parser_classes([MultiPartParser, FormParser])
def upload_event_poster(request, event_id):
    from django.conf import settings as dj_settings
    try:
        event = Event.objects.get(id=event_id, is_active=True)
    except Event.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    if not (event.organizer == request.user or _is_teacher(request.user)):
        return Response({"error": "Permission denied."}, status=403)

    file = request.FILES.get("poster")
    if not file:
        return Response({"error": "Poster file is required."}, status=400)

    max_bytes = getattr(dj_settings, "MAX_IMAGE_BYTES", 8 * 1024 * 1024)
    max_mb    = getattr(dj_settings, "MAX_IMAGE_MB",    8)
    allowed   = getattr(dj_settings, "ALLOWED_IMAGE_TYPES",
                        ["image/jpeg", "image/png", "image/webp", "image/gif"])
    if file.size > max_bytes:
        return Response({"error": f"Poster exceeds {max_mb} MB limit."}, status=400)
    if file.content_type not in allowed:
        return Response(
            {"error": f"'{file.content_type}' is not a supported image format."},
            status=400)

    event.image = file
    event.save(update_fields=["image"])

    poster_url = None
    try:
        poster_url = event.image.url
        if poster_url and not poster_url.startswith("http"):
            poster_url = request.build_absolute_uri(poster_url)
    except Exception:
        pass
    return Response({"success": True, "poster_url": poster_url}, status=201)


# ─────────────────────────────────────────────────────────────
# Phase 2 spec 10.3 — unified events + announcements carousel
# Wired by apps/events/urls.py:
#   path("highlights/", views.campus_highlights, ...)
# ─────────────────────────────────────────────────────────────
@api_view(["GET"])
def campus_highlights(request):
    from django.utils import timezone
    from .serializers import HighlightItemSerializer
    try:
        from apps.posts.models import Post
    except Exception:
        Post = None

    limit = min(int(request.query_params.get("limit", 10)), 50)
    items = []

    # Upcoming events (featured first)
    now = timezone.now()
    events_qs = (Event.objects
                      .filter(is_active=True, start_time__gte=now)
                      .select_related("organizer")
                      .order_by("-is_featured", "start_time")[:limit])
    for e in events_qs:
        try:
            card_url = e.image.url if e.image else None
        except Exception:
            card_url = None
        if card_url and not card_url.startswith("http"):
            try:
                card_url = request.build_absolute_uri(card_url)
            except Exception:
                pass
        items.append({
            "kind":       "event",
            "id":         str(e.id),
            "title":      e.title,
            "preview":    (e.description or "")[:200],
            "card_url":   card_url,
            "tag":        e.get_category_display(),
            "start_time": e.start_time,
            "location":   e.location,
            "created_at": e.created_at,
        })

    # Recent announcements (Post rows tagged post_type='announcement')
    if Post is not None:
        try:
            ann_qs = (Post.objects
                          .filter(post_type="announcement", visibility="public")
                          .exclude(is_flagged=True)
                          .select_related("author")
                          .prefetch_related("media_files")
                          .order_by("-created_at")[:limit])
            for p in ann_qs:
                first_media = p.media_files.first()
                card_url = None
                if first_media and getattr(first_media, "file", None):
                    try:
                        card_url = first_media.file.url
                        if not card_url.startswith("http"):
                            card_url = request.build_absolute_uri(card_url)
                    except Exception:
                        card_url = None
                items.append({
                    "kind":       "announcement",
                    "id":         str(p.id),
                    "title":      (p.content or "")[:80] or "Announcement",
                    "preview":    (p.content or "")[:200],
                    "card_url":   card_url,
                    "tag":        p.author.display_name if p.author_id else "Campus",
                    "start_time": None,
                    "location":   "",
                    "created_at": p.created_at,
                })
        except Exception:
            pass

    # Newest first, then cap.
    items.sort(key=lambda x: x.get("created_at"), reverse=True)
    items = items[:limit]
    ser = HighlightItemSerializer(items, many=True)
    return Response({"results": ser.data, "count": len(ser.data)})
