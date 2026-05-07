# apps/events/views.py
from django.db import transaction
from django.db.models import Q
from rest_framework import generics, serializers, status, filters
from rest_framework.decorators import api_view
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

    image_url   = serializers.SerializerMethodField()
    is_rsvped   = serializers.SerializerMethodField()
    is_full     = serializers.BooleanField(read_only=True)
    can_manage  = serializers.SerializerMethodField()

    class Meta:
        model  = Event
        fields = [
            "id", "title", "description", "category",
            "organizer_name", "organizer_role",
            "image",            # write
            "image_url",        # read
            "location",
            "is_online", "meeting_url", "start_time", "end_time",
            "max_attendees", "attendees_count", "is_featured",
            "is_full", "is_rsvped", "can_manage", "created_at",
        ]
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
        # When creating, we need either an uploaded `image` in the
        # incoming data OR (less likely) a poster supplied another way.
        if is_create and not attrs.get("image"):
            raise serializers.ValidationError({
                "image": "A poster image is required when creating an event.",
            })
        return attrs

    # ── Computed read fields ──────────────────────────────────

    def get_image_url(self, obj):
        req = self.context.get("request")
        if obj.image:
            try:
                return req.build_absolute_uri(obj.image.url) if req else obj.image.url
            except Exception:
                return None
        return None

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
        qs = Event.objects.filter(is_active=True).select_related("organizer")
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
        serializer.save(organizer=self.request.user)


# ─────────────────────────────────────────────────────────────
# Detail
# ─────────────────────────────────────────────────────────────

class EventDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = EventSerializer
    queryset         = Event.objects.filter(is_active=True)
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
        if not (event.organizer == request.user or _is_teacher(request.user)):
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