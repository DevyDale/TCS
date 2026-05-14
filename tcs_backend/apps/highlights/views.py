"""
apps/highlights/views.py

Story-style profile highlights. Structurally mirrors apps/posts:
  Highlight              <-> Post
  HighlightItem          <-> PostMedia
  upload_highlight_media <-> upload_post_media

The Cloudinary upload path is identical to posts. Validation reuses
apps.posts.views._validate_upload so the size/MIME rules stay in one
place.
"""
from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
import cloudinary.uploader

from apps.posts.views import _validate_upload
from .models import Highlight, HighlightItem
from .serializers import (
    HighlightSerializer, HighlightCompactSerializer,
    CreateHighlightSerializer, HighlightItemSerializer,
)

MAX_ITEMS_PER_HIGHLIGHT = 20


# ─────────────────────────────────────────────────────────────
# LIST + CREATE
# ─────────────────────────────────────────────────────────────

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


# ─────────────────────────────────────────────────────────────
# MY HIGHLIGHTS  (explicit, mirrors /posts/mine/)
# ─────────────────────────────────────────────────────────────

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


# ─────────────────────────────────────────────────────────────
# ANOTHER USER'S HIGHLIGHTS  (wired from accounts/user_urls.py)
# ─────────────────────────────────────────────────────────────

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


# ─────────────────────────────────────────────────────────────
# DETAIL
# ─────────────────────────────────────────────────────────────

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


# ─────────────────────────────────────────────────────────────
# MEDIA UPLOAD  - mirrors upload_post_media, plus is_cover routing
# ─────────────────────────────────────────────────────────────

@api_view(["POST"])
@parser_classes([MultiPartParser, FormParser])
def upload_highlight_media(request):
    """
    POST /api/highlights/upload/
    Multipart fields:
        highlight_id - UUID of the existing highlight (also accepts `highlight`)
        file         - image or video file
        media_type   - 'image' (default) or 'video'
        is_cover     - 'true' routes the file to Highlight.cover instead
                       of appending it as a story item
        duration     - optional per-item seconds for the story viewer
        caption      - optional per-item overlay text

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

    # ── Cover upload: set Highlight.cover, do NOT create a story item ──
    if is_cover:
        highlight.cover = file
        highlight.save()
        out = HighlightSerializer(highlight, context={"request": request})
        return Response(out.data, status=status.HTTP_200_OK)

    # ── Story item ────────────────────────────────────────────
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

    return Response(HighlightItemSerializer(item).data,
                    status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────
# DELETE A SINGLE ITEM  (nested under the highlight, per the client)
# ─────────────────────────────────────────────────────────────

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
