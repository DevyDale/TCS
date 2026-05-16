from apps.accounts.role_filter import filter_posts_by_role, cross_role_post_404
"""
apps/posts/views.py
"""
from django.conf import settings
from django.db.models import Q
from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
import cloudinary.uploader

from .models import (
    Feeling, Hashtag, Post, PostMedia, Like, Comment, Bookmark, PostFlag,
    attach_hashtags,
)
from .serializers import (
    FeelingSerializer, HashtagSerializer,
    PostSerializer, CreatePostSerializer,
    PostMediaSerializer, CommentSerializer,
)

MAX_IMAGES_PER_POST = 5


# ─────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────

def _mb(size_bytes: int) -> str:
    """Format bytes as a human-readable MB string, e.g. '9.3 MB'."""
    return f"{size_bytes / (1024 * 1024):.1f} MB"


def _validate_upload(file, media_type: str = "image"):
    """
    Validate file size and MIME type before touching Cloudinary.
    Returns (ok: bool, error_message: str | None).
    """
    if media_type == "video":
        max_bytes    = settings.MAX_VIDEO_BYTES
        max_mb       = settings.MAX_VIDEO_MB
        allowed_types = settings.ALLOWED_VIDEO_TYPES
    else:
        max_bytes    = settings.MAX_IMAGE_BYTES
        max_mb       = settings.MAX_IMAGE_MB
        allowed_types = settings.ALLOWED_IMAGE_TYPES

    if file.size > max_bytes:
        return False, (
            f"Your file is {_mb(file.size)}, which exceeds the "
            f"{max_mb} MB limit for {media_type}s. "
            f"Please compress it and try again."
        )

    if file.content_type not in allowed_types:
        friendly = ", ".join(t.split("/")[1].upper() for t in allowed_types)
        return False, (
            f"'{file.content_type}' is not a supported format. "
            f"Accepted {media_type} formats: {friendly}."
        )

    return True, None


# ─────────────────────────────────────────────────────────────
# PAGINATION
# ─────────────────────────────────────────────────────────────


class FeelingListView(generics.ListAPIView):
    """
    GET /api/feelings/  → list of active feelings, ordered by
    (sort_order, label). No pagination — list is small (~20 rows)
    and the client wants it all in one shot.
    """
    serializer_class   = FeelingSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = None
 
    def get_queryset(self):
        return Feeling.objects.filter(is_active=True)
 

class PostPagination(PageNumberPagination):
    page_size             = 20
    page_size_query_param = "page_size"
    max_page_size         = 50


# ─────────────────────────────────────────────────────────────
# POST LIST + CREATE
# ─────────────────────────────────────────────────────────────

class PostListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/posts/        — paginated list (?user_id= optional)
    POST /api/posts/        — create a text post (images via /upload/)
    """
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = PostPagination

    def get_serializer_class(self):
        if self.request.method == "POST":
            return CreatePostSerializer
        return PostSerializer

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        qs = (Post.objects
                  .select_related("author")
                  .prefetch_related("media_files", "hashtags")
                  .exclude(is_flagged=True))

        group_id = self.request.query_params.get("group_id")
        if group_id:
            qs = qs.filter(group_id=group_id, post_type="post")
        else:
            qs = qs.filter(visibility="public", group__isnull=True)

        user_id = self.request.query_params.get("user_id")
        if user_id:
            qs = qs.filter(author__user_id=user_id)

        return qs.order_by("-created_at")

    def create(self, request, *args, **kwargs):
        ser = CreatePostSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        post = ser.save(author=request.user)

        # Pull #hashtags out of the body and attach. Idempotent —
        # if the same tag appears twice in content it's only counted
        # once. See attach_hashtags() in models.py.
        attach_hashtags(post, post.content)

        out  = PostSerializer(post, context={"request": request})
        return Response(out.data, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────
# POST DETAIL
# ─────────────────────────────────────────────────────────────

    def perform_create(self, serializer):
        # Fweets are global. Strip any group context that may have leaked in
        # from the frontend (e.g. typing a fweet while a group screen is
        # mounted). A fweet with a group FK is always a bug.
        extra = {}
        if serializer.validated_data.get("post_type") == "fweet":
            extra["group"] = None
        serializer.save(**extra)


class PostDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET    /api/posts/<pk>/
    PATCH  /api/posts/<pk>/
    DELETE /api/posts/<pk>/
    """
    permission_classes = [permissions.IsAuthenticated]
    queryset = (Post.objects
                    .select_related("author")
                    .prefetch_related("media_files", "hashtags"))

    def get_queryset(self):
        return filter_posts_by_role(super().get_queryset(), self.request.user)

    def get_serializer_class(self):
        if self.request.method in ("PUT", "PATCH"):
            return CreatePostSerializer
        return PostSerializer

    def get_serializer_context(self):
        return {"request": self.request}

    def perform_update(self, serializer):
        # Re-extract hashtags whenever the post body changes, so a
        # user editing "Going to #OpenDay" → "Going to #ClosedDay"
        # updates posts_count on both tags correctly.
        post = serializer.save()
        attach_hashtags(post, post.content)

    def destroy(self, request, *args, **kwargs):
        post = self.get_object()
        if post.author != request.user and not request.user.is_staff:
            return Response({"error": "Not allowed."}, status=403)
        post.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)



# ─────────────────────────────────────────────────────────────
# SEARCH
# ─────────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def search_posts(request):
    """
    GET /api/posts/search/

    Phase 4 spec 8.2 — multi-field post search.

    Query params:
        q        — required search term (min 2 chars)
        field    — optional: 'caption' | 'location' | 'all' (default 'all')
        page     — optional pagination

    `caption` searches `Post.content` (which IS the caption in this app).
    `location` searches `Post.location`.
    `all` (default) searches both.

    Excludes flagged posts and respects visibility (only public + the
    viewer's own private posts come back).
    """
    q     = (request.query_params.get("q") or "").strip()
    field = (request.query_params.get("field") or "all").lower()

    if len(q) < 2:
        return Response({"results": [], "count": 0})

    me = request.user
    base = (Post.objects
                .select_related("author")
                .prefetch_related("media_files", "hashtags")
                .exclude(is_flagged=True)
                .filter(group__isnull=True)
                .filter(Q(visibility="public") | Q(author=me)))
    base = filter_posts_by_role(base, me)

    if field == "caption":
        qs = base.filter(content__icontains=q)
    elif field == "location":
        qs = base.filter(location__icontains=q)
    else:  # 'all'
        qs = base.filter(Q(content__icontains=q) | Q(location__icontains=q))

    qs = qs.order_by("-created_at")

    paginator = PostPagination()
    page      = paginator.paginate_queryset(qs, request)
    ser       = PostSerializer(page, many=True, context={"request": request})
    return paginator.get_paginated_response(ser.data)

# ─────────────────────────────────────────────────────────────
# FEED
# ─────────────────────────────────────────────────────────────
class FeedView(generics.ListAPIView):
    """
    GET /api/posts/feed/?type=home|following|trending|announcements|club_posts&page=1

    Phase 6: added `club_posts` type. Returns posts attached to clubs
    the viewer is an active member of, plus public club posts from
    any club. This powers the "Clubs" tab in the campus feed.
    """
    serializer_class   = PostSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = PostPagination

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        feed_type = self.request.query_params.get("type", "home")
        me        = self.request.user
        base = (Post.objects
                    .select_related("author", "club")
                    .prefetch_related("media_files", "hashtags")
                    .filter(group__isnull=True)
                    .exclude(is_flagged=True))
        base = filter_posts_by_role(base, me)

        if feed_type == "announcements":
            return base.filter(post_type="announcement").order_by("-created_at")

        # ── NEW: Club Posts tab ─────────────────────────────────
        if feed_type == "club_posts":
            from apps.clubs.models import ClubMember
            my_club_ids = ClubMember.objects.filter(
                user=me, status="active"
            ).values_list("club_id", flat=True)
            return (base
                    .filter(club__isnull=False)
                    .filter(
                        Q(club_id__in=my_club_ids) |
                        Q(visibility="public")
                    )
                    .distinct()
                    .order_by("-created_at"))

        if feed_type == "following":
            following_ids = me.following.values_list("id", flat=True)
            return (base
                    .filter(author__in=following_ids,
                            visibility__in=["public", "followers"])
                    .order_by("-created_at"))

        if feed_type == "trending":
            return (base
                    .filter(visibility="public")
                    .order_by("-likes_count", "-created_at"))

        # home — own posts + following + public
        following_ids = me.following.values_list("id", flat=True)
        return (base.filter(
            Q(author=me) |
            Q(author__in=following_ids,
              visibility__in=["public", "followers"]) |
            Q(visibility="public")
        ).distinct().order_by("-created_at"))


# ─────────────────────────────────────────────────────────────
# MY POSTS
# ─────────────────────────────────────────────────────────────

class MyPostsView(generics.ListAPIView):
    """GET /api/posts/mine/?post_type=post|fweet"""
    serializer_class   = PostSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = PostPagination

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        post_type = self.request.query_params.get("post_type", "post")
        return (Post.objects
                    .select_related("author")
                    .prefetch_related("media_files", "hashtags")
                    .filter(author=self.request.user, post_type=post_type)
                    .filter(group__isnull=True)
                    .exclude(is_flagged=True)
                    .order_by("-created_at"))

class BookmarkListView(generics.ListAPIView):
    """GET /api/posts/bookmarks/"""
    serializer_class   = PostSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = PostPagination

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        ids = Bookmark.objects.filter(
            user=self.request.user
        ).values_list("post_id", flat=True)
        return (Post.objects
                    .select_related("author")
                    .prefetch_related("media_files", "hashtags")
                    .filter(id__in=ids)
                    .order_by("-created_at"))


# ─────────────────────────────────────────────────────────────
# MEDIA UPLOAD  ← main Cloudinary entry point
# ─────────────────────────────────────────────────────────────

@api_view(["POST"])
@parser_classes([MultiPartParser, FormParser])
def upload_post_media(request):
    """
    POST /api/posts/upload/
    Multipart fields:
        post_id    — UUID of the existing post
        file       — image or video file
        media_type — 'image' (default) or 'video'

    Validation order:
      1. post_id present and belongs to requesting user
      2. file present
      3. file size within limit  (8 MB images / 50 MB videos)
      4. MIME type allowed
      5. per-post image cap (max 5)

    On success Django assigns the file to PostMedia.file (a CloudinaryField).
    django-cloudinary-storage uploads to Cloudinary automatically on save().
    Returns the PostMedia object including the Cloudinary URL.
    """
    post_id    = request.data.get("post_id", "").strip()
    file       = request.FILES.get("file")
    media_type = request.data.get("media_type", "image").strip()

    # ── 1. post_id ────────────────────────────────────────────
    if not post_id:
        return Response({"error": "post_id is required."}, status=400)

    try:
        post = Post.objects.get(pk=post_id, author=request.user)
    except Post.DoesNotExist:
        return Response({"error": "Post not found."}, status=404)

    # ── 2. file present ───────────────────────────────────────
    if not file:
        return Response({"error": "No file was provided."}, status=400)

    # ── 3 + 4. size and MIME validation ───────────────────────
    ok, err = _validate_upload(file, media_type)
    if not ok:
        return Response({"error": err}, status=400)

    # ── 5. per-post image cap ─────────────────────────────────
    current_count = post.media_files.count()
    if current_count >= MAX_IMAGES_PER_POST:
        return Response(
            {"error": f"A post can have at most {MAX_IMAGES_PER_POST} media files."},
            status=400)

    # ── Upload to Cloudinary ───────────────────────────────────
    if media_type == "video":
        upload_result = cloudinary.uploader.upload(
            file, resource_type="video", folder="tcs_studenthub/posts")
        media = PostMedia.objects.create(
            post=post, file=upload_result["public_id"],
            media_type="video", order=current_count)
    else:
        media = PostMedia.objects.create(
            post=post, file=file, media_type="image", order=current_count)

    return Response(PostMediaSerializer(media).data, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────
# AVATAR / COVER / ARCADE AVATAR uploads are in accounts/views.py
# They follow the same _validate_upload() pattern.
# ─────────────────────────────────────────────────────────────


# ─────────────────────────────────────────────────────────────
# LIKE
# ─────────────────────────────────────────────────────────────

@api_view(["POST"])
def like_toggle(request, pk):
    """POST /api/posts/<pk>/like/"""
    try:
        post = filter_posts_by_role(Post.objects, request.user).get(pk=pk)
    except Post.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    like, created = Like.objects.get_or_create(post=post, user=request.user)
    if not created:
        like.delete()
        post.likes_count = max(0, post.likes_count - 1)
        liked = False
    else:
        post.likes_count += 1
        liked = True

    post.save(update_fields=["likes_count"])
    return Response({"liked": liked, "like_count": post.likes_count})


# ─────────────────────────────────────────────────────────────
# BOOKMARK
# ─────────────────────────────────────────────────────────────

@api_view(["POST"])
def bookmark_toggle(request, pk):
    """POST /api/posts/<pk>/bookmark/"""
    try:
        post = filter_posts_by_role(Post.objects, request.user).get(pk=pk)
    except Post.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    bm, created = Bookmark.objects.get_or_create(post=post, user=request.user)
    if not created:
        bm.delete()
        bookmarked = False
    else:
        bookmarked = True

    return Response({"bookmarked": bookmarked})


# ─────────────────────────────────────────────────────────────
# SHARE
# ─────────────────────────────────────────────────────────────

@api_view(["POST"])
def share_post(request, pk):
    """POST /api/posts/<pk>/share/  body: {user_ids: [...]}"""
    try:
        post = filter_posts_by_role(Post.objects, request.user).get(pk=pk)
    except Post.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    post.shares_count += 1
    post.save(update_fields=["shares_count"])
    return Response({"shared": True, "share_count": post.shares_count})


# ─────────────────────────────────────────────────────────────
# FLAG
# ─────────────────────────────────────────────────────────────

@api_view(["POST"])
def flag_post(request, pk):
    """POST /api/posts/<pk>/flag/  body: {reason: '...'}"""
    try:
        post = filter_posts_by_role(Post.objects, request.user).get(pk=pk)
    except Post.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    PostFlag.objects.get_or_create(
        post     = post,
        user     = request.user,
        defaults = {"reason": request.data.get("reason", "other")},
    )
    return Response({"flagged": True})


# ─────────────────────────────────────────────────────────────
# COMMENTS
# ─────────────────────────────────────────────────────────────

class CommentListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/posts/<pk>/comments/
    POST /api/posts/<pk>/comments/  body: {text, parent_id?}
    """
    serializer_class   = CommentSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = PostPagination

    def get_serializer_context(self):
        return {"request": self.request}

    def get_queryset(self):
        return (Comment.objects
                       .select_related("author")
                       .filter(post_id=self.kwargs["pk"],
                               is_deleted=False,
                               parent=None)
                       .order_by("-created_at"))

    def perform_create(self, serializer):
        post = filter_posts_by_role(Post.objects, self.request.user).get(pk=self.kwargs["pk"])
        serializer.save(author=self.request.user, post=post)
        post.comments_count += 1
        post.save(update_fields=["comments_count"])


# ─────────────────────────────────────────────────────────────
# HASHTAGS  &  FEELINGS  (function-based list views)
#
# Wired by apps/posts/urls.py:
#   path("hashtags/", views.list_hashtags, name="hashtags-list")
#   path("feelings/", views.list_feelings, name="feelings-list")
#
# `FeelingListView` (class-based) above is a separate, parallel
# entry point at /api/feelings/. Both can coexist — they hit the
# same data through different URLs.
# ─────────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def list_hashtags(request):
    """
    GET /api/posts/hashtags/?q=&limit=
        ?q       — optional prefix filter (case-insensitive on slug)
        ?limit   — optional, default 30, max 100

    Returns trending hashtags ordered by posts_count desc, with
    last_used_at desc as a tiebreaker so a tag that was just used
    edges out one that hasn't been touched in a month.
    """
    q     = (request.query_params.get("q") or "").strip().lower()
    limit = min(int(request.query_params.get("limit", 30)), 100)

    qs = Hashtag.objects.all()
    if q:
        qs = qs.filter(slug__startswith=q)
    qs = qs.order_by("-posts_count", "-last_used_at")[:limit]
    return Response(HashtagSerializer(qs, many=True).data)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def list_feelings(request):
    """
    GET /api/posts/feelings/  — function-based companion to the
    /api/feelings/ class-based view (FeelingListView). Returns
    active feelings ordered by sort_order, then label.
    """
    qs = Feeling.objects.filter(is_active=True).order_by("sort_order", "label")
    return Response(FeelingSerializer(qs, many=True).data)