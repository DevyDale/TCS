# Phase 4 — Posts search endpoint

The existing `frontend/lib/screens/search_screen.dart` calls
`/api/posts/search/` but no such route exists in `apps/posts/urls.py`.
That's why post search has been quietly returning errors. Phase 4 adds
the real endpoint so the new search screen has something to call.

This is a TWO-FILE patch — one new view function in `views.py`, one
new URL pattern in `urls.py`. Apply by hand.

---

## 1. `tcs_backend/apps/posts/views.py`

Find the FEED view block (or any of the existing `@api_view` functions
near the top). Just before the `# ── FEED ──` divider, paste this in:

```python
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
                .prefetch_related("media_files")
                .exclude(is_flagged=True)
                .filter(Q(visibility="public") | Q(author=me)))

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
```

Confirm `Q` is already imported at the top of the file. It should be —
the existing `FeedView` uses `Q(author=me) | Q(...)` etc. If for some
reason it isn't, add `from django.db.models import Q` to the imports.

---

## 2. `tcs_backend/apps/posts/urls.py`

Find the urlpatterns list and add ONE line. Put it right after the
`feed/` route to keep search-related URLs grouped:

```python
urlpatterns = [
    # ── List / Create ─────────────────────────────────────────
    path('',                views.PostListCreateView.as_view(),  name='post-list'),

    # ── Feed ──────────────────────────────────────────────────
    path('feed/',           views.FeedView.as_view(),            name='post-feed'),

    # ── Search (Phase 4) ──────────────────────────────────────
    path('search/',         views.search_posts,                   name='post-search'),

    # ── My posts + bookmarks ──────────────────────────────────
    path('mine/',           views.MyPostsView.as_view(),         name='post-mine'),
    path('bookmarks/',      views.BookmarkListView.as_view(),     name='post-bookmarks'),

    # ... rest unchanged ...
]
```

Done. No migration needed — this is read-only and uses existing fields.

---

## Smoke test

After patching, restart the dev server and try:

```bash
# Replace TOKEN with a valid access token (grab it from
# SharedPreferences or by logging in and inspecting the response)
TOKEN="your-access-token"

# Caption search
curl -H "Authorization: Bearer $TOKEN" \
     "http://127.0.0.1:8000/api/posts/search/?q=hello&field=caption"

# Location search
curl -H "Authorization: Bearer $TOKEN" \
     "http://127.0.0.1:8000/api/posts/search/?q=library&field=location"

# Both
curl -H "Authorization: Bearer $TOKEN" \
     "http://127.0.0.1:8000/api/posts/search/?q=campus"
```

Each should return `{"count": N, "next": ..., "previous": ..., "results": [...]}`.

If `q` is too short (< 2 chars), you get an empty result set —
intentional, matches the existing `search_users` view's behaviour.
