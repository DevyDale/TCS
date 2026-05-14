"""
apps/highlights/views.py

Story-style profile highlights. Structurally mirrors apps/posts.
Per-item likes and comments mirror the posts Like/Comment endpoints,
scoped to a HighlightItem.
"""
from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.exceptions import NotFound
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
import cloudinary.uploader

from apps.posts.views import _validate_upload
from .models import (
    Highlight, HighlightItem, HighlightItemLike, HighlightItemComment,
)
from .serializers import (
    HighlightSerializer, HighlightCompactSerializer,
    CreateHighlightSerializer, HighlightItemSerializer,
    HighlightItemCommentSerializer,
)

MAX_ITEMS_PER_HIGHLIGHT = 20


class HighlightListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/highlights/            - my highlights (compact)
    GET  /api/highlights/?user_id=X  - another user's highlights
    POST /api/highlights/            - create an empty highlight {title}
    """
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == "POST":
            return CreateHighlightSerializer
        return HighlightCompactSerializer

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        qs = (Highlight.objects
                       .select_related("owner")
                       .prefetch_related("items")
                       .filter(is_archived=False))
        user_id = self.request.query_params.get("user_id")
        if user_id:
            qs = qs.filter(owner__user_id=user_id)
        else:
            qs = qs.filter(owner=self.request.user)
        return qs.order_by("-created_at")

    def create(self, request, *args, **kwargs):
        ser = CreateHighlightSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        highlight = ser.save(owner=request.user)
        out = HighlightSerializer(highlight, context={"request": request})
        return Response(out.data, status=status.HTTP_201_CREATED)


class HighlightsFeedView(generics.ListAPIView):
    """
    GET /api/highlights/feed/

    Every user's highlights, newest first - powers the Highlights row
    on the campus feed. Only non-archived highlights that have at least
    one story item are returned.
    """
    serializer_class   = HighlightCompactSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        return (Highlight.objects
                         .select_related("owner")
                         .prefetch_related("items")
                         .filter(is_archived=False)
                         .exclude(items__isnull=True)
                         .distinct()
                         .order_by("-created_at"))


class MyHighlightsView(generics.ListAPIView):
    """GET /api/highlights/mine/"""
    serializer_class   = HighlightCompactSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        return (Highlight.objects
                         .select_related("owner")
                         .prefetch_related("items")
                         .filter(owner=self.request.user, is_archived=False)
                         .order_by("-created_at"))


class UserHighlightsView(generics.ListAPIView):
    """GET /api/users/<user_id>/highlights/"""
    serializer_class   = HighlightCompactSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        return (Highlight.objects
                         .select_related("owner")
                         .prefetch_related("items")
                         .filter(owner__user_id=self.kwargs["user_id"],
                                 is_archived=False)
                         .order_by("-created_at"))


class HighlightDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET    /api/highlights/<pk>/  - full highlight + ordered items
    PATCH  /api/highlights/<pk>/  - rename / archive
    DELETE /api/highlights/<pk>/  - owner only
    """
    permission_classes = [permissions.IsAuthenticated]
    queryset = (Highlight.objects
                         .select_related("owner")
                         .prefetch_related("items"))

    def get_serializer_class(self):
        if self.request.method in ("PUT", "PATCH"):
            return CreateHighlightSerializer
        return HighlightSerializer

    def get_serializer_context(self):
        return {"request": self.request}

    def destroy(self, request, *args, **kwargs):
        highlight = self.get_object()
        if highlight.owner != request.user and not request.user.is_staff:
            return Response({"error": "Not allowed."}, status=403)
        highlight.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
@parser_classes([MultiPartParser, FormParser])
def upload_highlight_media(request):
    """
    POST /api/highlights/upload/
    Fields: highlight_id, file, media_type, is_cover, duration, caption.
    Same validation + Cloudinary path as upload_post_media.
    """
    highlight_id = (request.data.get("highlight_id")
                    or request.data.get("highlight")
                    or "").strip()
    file         = request.FILES.get("file")
    media_type   = request.data.get("media_type", "image").strip()
    is_cover     = str(request.data.get("is_cover", "")).strip().lower() == "true"

    if not highlight_id:
        return Response({"error": "highlight_id is required."}, status=400)

    try:
        highlight = Highlight.objects.get(pk=highlight_id, owner=request.user)
    except Highlight.DoesNotExist:
        return Response({"error": "Highlight not found."}, status=404)

    if not file:
        return Response({"error": "No file was provided."}, status=400)

    ok, err = _validate_upload(file, media_type)
    if not ok:
        return Response({"error": err}, status=400)

    if is_cover:
        highlight.cover = file
        highlight.save()
        out = HighlightSerializer(highlight, context={"request": request})
        return Response(out.data, status=status.HTTP_200_OK)

    current_count = highlight.items.count()
    if current_count >= MAX_ITEMS_PER_HIGHLIGHT:
        return Response(
            {"error": f"A highlight can have at most {MAX_ITEMS_PER_HIGHLIGHT} items."},
            status=400)

    try:
        duration = int(request.data.get("duration", 5))
    except (TypeError, ValueError):
        duration = 5
    caption = (request.data.get("caption") or "").strip()

    if media_type == "video":
        upload_result = cloudinary.uploader.upload(
            file, resource_type="video", folder="tcs_studenthub/highlights")
        item = HighlightItem.objects.create(
            highlight=highlight, file=upload_result["public_id"],
            media_type="video", order=current_count,
            duration=duration, caption=caption)
    else:
        item = HighlightItem.objects.create(
            highlight=highlight, file=file, media_type="image",
            order=current_count, duration=duration, caption=caption)

    return Response(
        HighlightItemSerializer(item, context={"request": request}).data,
        status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
@permission_classes([permissions.IsAuthenticated])
def delete_highlight_item(request, highlight_id, pk):
    """DELETE /api/highlights/<highlight_id>/items/<pk>/"""
    try:
        item = HighlightItem.objects.select_related("highlight").get(
            pk=pk, highlight_id=highlight_id)
    except HighlightItem.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    if item.highlight.owner != request.user and not request.user.is_staff:
        return Response({"error": "Not allowed."}, status=403)
    item.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def toggle_item_like(request, item_id):
    """
    POST /api/highlights/items/<item_id>/like/
    Toggles the user's like on one story item. Returns {liked, like_count}.
    """
    try:
        item = HighlightItem.objects.get(pk=item_id)
    except HighlightItem.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    like, created = HighlightItemLike.objects.get_or_create(
        item=item, user=request.user)
    if not created:
        like.delete()
        liked = False
    else:
        liked = True

    return Response({"liked": liked, "like_count": item.likes.count()})


class HighlightItemCommentsView(generics.ListCreateAPIView):
    """
    GET  /api/highlights/items/<item_id>/comments/   - oldest-first
    POST /api/highlights/items/<item_id>/comments/   - body: {text}
    """
    serializer_class   = HighlightItemCommentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        return (HighlightItemComment.objects
                                    .select_related("author")
                                    .filter(item_id=self.kwargs["item_id"])
                                    .order_by("created_at"))

    def perform_create(self, serializer):
        try:
            item = HighlightItem.objects.get(pk=self.kwargs["item_id"])
        except HighlightItem.DoesNotExist:
            raise NotFound("Highlight item not found.")
        serializer.save(author=self.request.user, item=item)
