from django.db import transaction
from django.db.models import Q
from rest_framework import generics, serializers, status, filters
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Event, EventRSVP


TEACHER_ROLES = {"teaching_staff", "admin"}


def _is_teacher(user):
    return user.role in TEACHER_ROLES


class EventSerializer(serializers.ModelSerializer):
    organizer_name = serializers.CharField(source="organizer.display_name", read_only=True)
    organizer_role = serializers.CharField(source="organizer.role",         read_only=True)
    image_url      = serializers.SerializerMethodField()
    is_rsvped      = serializers.SerializerMethodField()
    is_full        = serializers.BooleanField(read_only=True)
    can_manage     = serializers.SerializerMethodField()

    class Meta:
        model  = Event
        fields = [
            "id", "title", "description", "category",
            "organizer_name", "organizer_role", "image_url", "location",
            "is_online", "meeting_url", "start_time", "end_time",
            "max_attendees", "attendees_count", "is_featured",
            "is_full", "is_rsvped", "can_manage", "created_at",
        ]
        read_only_fields = ["id", "attendees_count", "created_at"]

    def get_image_url(self, obj):
        req = self.context.get("request")
        if obj.image:
            return req.build_absolute_uri(obj.image.url) if req else obj.image.url
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


class EventListCreateView(generics.ListCreateAPIView):
    serializer_class = EventSerializer
    filter_backends  = [filters.SearchFilter, filters.OrderingFilter]
    search_fields    = ["title", "description", "location"]
    ordering_fields  = ["start_time", "attendees_count", "created_at"]
    ordering         = ["start_time"]

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


class EventDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = EventSerializer
    queryset         = Event.objects.filter(is_active=True)

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


@api_view(["POST"])
def rsvp_toggle(request, event_id):
    try:
        event = Event.objects.get(id=event_id, is_active=True)
    except Event.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    with transaction.atomic():
        rsvp, created = EventRSVP.objects.get_or_create(event=event, user=request.user)
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
    return Response({"action": action, "attendees_count": event.attendees_count})


@api_view(["GET"])
def my_events(request):
    events = Event.objects.filter(rsvps__user=request.user, is_active=True)
    return Response(EventSerializer(events, many=True, context={"request": request}).data)


@api_view(["GET"])
def teacher_events(request):
    """GET /api/events/managed/ — events created by the current teacher."""
    if not _is_teacher(request.user):
        return Response({"error": "Permission denied."}, status=403)
    events = Event.objects.filter(organizer=request.user, is_active=True)
    return Response(EventSerializer(events, many=True, context={"request": request}).data)