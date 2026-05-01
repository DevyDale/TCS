from django.contrib import admin
from .models import Game, GameScore, GameRequest


@admin.register(Game)
class GameAdmin(admin.ModelAdmin):
    list_display  = ["name", "slug", "category", "xp_reward",
                     "token_reward", "play_count", "is_featured", "is_active"]
    list_filter   = ["category", "is_active", "is_featured"]
    search_fields = ["name", "slug"]
    prepopulated_fields = {"slug": ("name",)}
    readonly_fields = ["id", "play_count"]

    actions = ["feature", "unfeature"]

    @admin.action(description="⭐ Feature")
    def feature(self, r, qs): qs.update(is_featured=True)

    @admin.action(description="Remove featured")
    def unfeature(self, r, qs): qs.update(is_featured=False)


@admin.register(GameScore)
class GameScoreAdmin(admin.ModelAdmin):
    list_display  = ["user", "game", "score", "played_at"]
    list_filter   = ["game"]
    ordering      = ["-score"]
    readonly_fields = ["played_at"]


@admin.register(GameRequest)
class GameRequestAdmin(admin.ModelAdmin):
    list_display  = ["sender", "receiver", "game_slug", "game_name", "wager", "status", "created_at"]
    list_filter   = ["status"]
    readonly_fields = ["id", "created_at"]
