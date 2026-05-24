# apps/events/serializers.py
#
# Extracted from views.py in Phase 2 so we can also import these serializers
# from apps/posts when building the unified campus-highlights endpoint.

from rest_framework import serializers
import cloudinary

from .models import Event, EventRSVP


def _cl(field_value, **opts):
    """Build an optimised Cloudinary URL from a CloudinaryField value."""
    if not field_value:
        return None
    try:
        return cloudinary.CloudinaryImage(str(field_value)).build_url(**opts)
    except Exception:
        return None


# Roles that can create/manage events.
TEACHER_ROLES = {"teaching_staff", "admin"}


def is_teacher(user):
    return getattr(user, "role", None) in TEACHER_ROLES


class EventSerializer(serializers.ModelSerializer):
    """
    Read-side serializer used by GET /events/, GET /events/<id>/, and
    GET /events/highlights/. Returns Cloudinary URLs at two sizes:
      - poster_url: full-bleed for detail screen (1200×wide, fit)
      - card_url:   carousel/list card (800×wide, fit)
    """

    organizer_name = serializers.CharField(source="organizer.display_name", read_only=True)
    organizer_role = serializers.CharField(source="organizer.role",         read_only=True)
    poster_url     = serializers.SerializerMethodField()
    card_url       = serializers.SerializerMethodField()
    # Kept for backwards compatibility with the old EventSerializer field name.
    image_url      = serializers.SerializerMethodField()

    rsvp_status    = serializers.SerializerMethodField()
    is_rsvped      = serializers.SerializerMethodField()
    is_full        = serializers.BooleanField(read_only=True)
    can_manage     = serializers.SerializerMethodField()

    going_count       = serializers.SerializerMethodField()
    interested_count  = serializers.SerializerMethodField()

    class Meta:
        model  = Event
        fields = [
            "id", "title", "description", "category",
            "organizer_name", "organizer_role",
            "poster_url", "card_url", "image_url",
            "location", "is_online", "meeting_url",
            "start_time", "end_time",
            "max_attendees", "attendees_count",
            "going_count", "interested_count",
            "is_featured", "is_full",
            "rsvp_status", "is_rsvped", "can_manage",
            "created_at",
        ]
        read_only_fields = ["id", "attendees_count", "created_at"]

    def get_poster_url(self, obj):
        return _cl(obj.image,
                   width=1200, crop="limit",
                   fetch_format="auto", quality="auto", secure=True)

    def get_card_url(self, obj):
        return _cl(obj.image,
                   width=800, height=600, crop="fill", gravity="center",
                   fetch_format="auto", quality="auto", secure=True)

    def get_image_url(self, obj):
        # Backwards compat: same shape as the v1 serializer used.
        return self.get_card_url(obj)

    def _my_rsvp(self, obj):
        req = self.context.get("request")
        if not (req and req.user.is_authenticated):
            return None
        return EventRSVP.objects.filter(event=obj, user=req.user).first()

    def get_rsvp_status(self, obj):
        """Returns 'going' | 'interested' | 'not_going' | null."""
        rsvp = self._my_rsvp(obj)
        return rsvp.status if rsvp else None

    def get_is_rsvped(self, obj):
        # Backwards compat: True only if the user is GOING.
        rsvp = self._my_rsvp(obj)
        return bool(rsvp and rsvp.status == EventRSVP.Status.GOING)

    def get_can_manage(self, obj):
        req = self.context.get("request")
        if not (req and req.user.is_authenticated):
            return False
        return obj.organizer == req.user or is_teacher(req.user)

    def get_going_count(self, obj):
        # attendees_count is maintained by the view as the GOING count.
        return obj.attendees_count

    def get_interested_count(self, obj):
        return obj.rsvps.filter(status=EventRSVP.Status.INTERESTED).count()


class EventCreateSerializer(serializers.ModelSerializer):
    """
    Write-side serializer used by POST /events/ and PATCH /events/<id>/.
    The poster image is uploaded separately via POST /events/<id>/poster/
    so that event creation works as a JSON-only request (matches the
    pattern used for posts: create text first, attach media after).
    """

    class Meta:
        model  = Event
        fields = [
            "title", "description", "category", "group", "club",
            "location", "is_online", "meeting_url",
            "start_time", "end_time",
            "max_attendees", "is_featured",
            "club",]


class HighlightItemSerializer(serializers.Serializer):
    """
    Polymorphic carousel item for GET /events/highlights/. Each item is
    either an event or an announcement, distinguished by the `kind` field.

    Frontend reads:
        {
          "kind": "event" | "announcement",
          "id": "<uuid>",
          "title": "...",
          "preview": "...",          # description / content snippet
          "card_url": "...",         # poster / first media image
          "tag": "Sports" | "Math Society" | ...,   # category or author
          "start_time": "...",       # events only
          "location": "...",         # events only
          "created_at": "..."
        }
    """
    kind        = serializers.CharField()
    id          = serializers.CharField()
    title       = serializers.CharField()
    preview     = serializers.CharField(allow_blank=True)
    card_url    = serializers.URLField(allow_null=True)
    tag         = serializers.CharField(allow_blank=True)
    start_time  = serializers.DateTimeField(allow_null=True, required=False)
    location    = serializers.CharField(allow_blank=True, required=False)
    created_at  = serializers.DateTimeField()
