from django.contrib import admin
from .models import Post, Comment, Bookmark, PostFlag, Hashtag, Feeling


@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display  = ["id", "author", "post_type", "visibility",
                     "likes_count", "is_flagged", "is_pinned", "created_at"]
    list_filter   = ["post_type", "visibility", "is_flagged", "is_pinned"]
    search_fields = ["content", "author__name"]
    readonly_fields = ["id", "likes_count", "comments_count", "views_count", "created_at"]

    actions = ["pin_posts", "unpin_posts", "flag_posts", "unflag_posts"]

    @admin.action(description="📌 Pin")
    def pin_posts(self, r, qs): qs.update(is_pinned=True)

    @admin.action(description="Unpin")
    def unpin_posts(self, r, qs): qs.update(is_pinned=False)

    @admin.action(description="🚫 Flag")
    def flag_posts(self, r, qs): qs.update(is_flagged=True)

    @admin.action(description="✅ Unflag")
    def unflag_posts(self, r, qs): qs.update(is_flagged=False)


@admin.register(Comment)
class CommentAdmin(admin.ModelAdmin):
    list_display  = ["id", "author", "post", "is_deleted", "created_at"]
    search_fields = ["text", "author__name"]
    readonly_fields = ["created_at"]


@admin.register(PostFlag)
class PostFlagAdmin(admin.ModelAdmin):
    list_display = ["post", "user", "reason", "created_at"]
    readonly_fields = ["created_at"]


@admin.register(Hashtag)
class HashtagAdmin(admin.ModelAdmin):
    list_display    = ["display", "slug", "posts_count", "last_used_at"]
    search_fields   = ["slug", "display"]
    readonly_fields = ["slug", "first_seen_at", "last_used_at", "posts_count"]
    ordering        = ["-posts_count"]


@admin.register(Feeling)
class FeelingAdmin(admin.ModelAdmin):
    """
    Inline-edit sort_order and is_active straight from the changelist
    so admins can rearrange / retire feelings without opening each row.
    """
    list_display    = ["emoji", "label", "slug", "category",
                       "sort_order", "is_active"]
    list_editable   = ["sort_order", "is_active"]
    list_filter     = ["category", "is_active"]
    search_fields   = ["slug", "label", "category"]
    ordering        = ["sort_order", "label"]