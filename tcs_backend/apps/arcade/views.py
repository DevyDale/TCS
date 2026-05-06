from django.db.models import Max, Count, Q
from django.contrib.auth import get_user_model
from rest_framework import serializers, status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Game, GameScore, GameRequest

User = get_user_model()


class GameSerializer(serializers.ModelSerializer):
    my_best_score = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()

    class Meta:
        model  = Game
        fields = ["id", "name", "slug", "description", "category",
                  "thumbnail_url", "min_players", "max_players",
                  "xp_reward", "token_reward", "is_featured",
                  "play_count", "my_best_score"]

    def get_thumbnail_url(self, obj):
        req = self.context.get("request")
        if obj.thumbnail:
            return req.build_absolute_uri(obj.thumbnail.url) if req else obj.thumbnail.url
        return None

    def get_my_best_score(self, obj):
        req = self.context.get("request")
        if req and req.user.is_authenticated:
            r = GameScore.objects.filter(game=obj, user=req.user).aggregate(Max("score"))
            return r["score__max"]
        return None


class GameRequestSerializer(serializers.ModelSerializer):
    from_user_name   = serializers.CharField(source="from_user.display_name", read_only=True)
    from_user_avatar = serializers.SerializerMethodField()
    to_user_name     = serializers.CharField(source="to_user.display_name",   read_only=True)
    game_name        = serializers.CharField(source="game.name",              read_only=True)
    game_slug        = serializers.CharField(source="game.slug",              read_only=True)

    class Meta:
        model  = GameRequest
        fields = ["id", "from_user_name", "from_user_avatar",
                  "to_user_name", "game_name", "game_slug",
                  "status", "created_at"]

    def get_from_user_avatar(self, obj):
        req = self.context.get("request")
        if obj.from_user.avatar:
            return req.build_absolute_uri(obj.from_user.avatar.url) if req else obj.from_user.avatar.url
        return None


@api_view(["GET"])
def token_wallet(request):
    """GET /api/arcade/tokens/ — returns the user's token balance and history."""
    return Response({
        "tokens":    request.user.tokens,
        "level":     request.user.level,
        "xp":        request.user.xp,
        "gamer_tag": request.user.gamer_tag or "",
    })


@api_view(["GET"])
def game_list(request):
    games = Game.objects.filter(is_active=True).order_by("-is_featured", "-play_count")
    return Response(GameSerializer(games, many=True, context={"request": request}).data)


@api_view(["GET"])
def leaderboard(request):
    slug  = request.query_params.get("game")
    limit = min(int(request.query_params.get("limit", 20)), 100)

    if slug:
        try:
            game = Game.objects.get(slug=slug)
        except Game.DoesNotExist:
            return Response({"error": "Game not found."}, status=404)
        rows = (
            GameScore.objects.filter(game=game)
            .values("user__user_id", "user__name", "user__preferred_name",
                    "user__level", "user__gamer_tag")
            .annotate(best=Max("score"), games_played=Count("id"))
            .order_by("-best")[:limit]
        )
        return Response([
            {
                "rank":         i + 1,
                "user_id":      r["user__user_id"],
                "display_name": r["user__preferred_name"] or r["user__name"] or "Player",
                "gamer_tag":    r["user__gamer_tag"] or "",
                "score":        r["best"],
                "level":        r["user__level"],
                "games_played": r["games_played"],
            }
            for i, r in enumerate(rows)
        ])

    # Global leaderboard — by XP
    users = User.objects.filter(is_active=True).order_by("-xp")[:limit]
    return Response([
        {
            "rank":         i + 1,
            "user_id":      u.user_id,
            "display_name": u.display_name,
            "gamer_tag":    u.gamer_tag or "",
            "score":        u.xp,
            "level":        u.level,
            "tokens":       u.tokens,
        }
        for i, u in enumerate(users)
    ])


@api_view(["POST"])
def submit_score(request):
    """
    POST /api/arcade/score/
    Body: { "game": "slug", "score": 1234, "bonus_tokens": 0 }

    Token calculation:
      base = game.token_reward
      performance bonus = min(score // 100, 50)   (up to +50 extra)
      bonus_tokens from client (for speed bonuses etc, capped at 30)
    """
    slug         = request.data.get("game", "")
    score        = max(0, int(request.data.get("score", 0)))
    bonus_tokens = min(30, max(0, int(request.data.get("bonus_tokens", 0))))

    try:
        game = Game.objects.get(slug=slug, is_active=True)
    except Game.DoesNotExist:
        return Response({"error": "Game not found."}, status=404)

    # Save score
    GameScore.objects.create(game=game, user=request.user, score=score)
    Game.objects.filter(pk=game.pk).update(play_count=game.play_count + 1)

    # Performance-based token reward
    perf_bonus  = min(score // 100, 50)
    total_tokens = game.token_reward + perf_bonus + bonus_tokens

    request.user.add_xp(game.xp_reward)
    request.user.tokens = request.user.tokens + total_tokens
    request.user.save(update_fields=["tokens"])

    # My rank for this game
    rank = (
        GameScore.objects.filter(game=game, score__gt=score)
        .values("user").distinct().count() + 1
    )

    return Response({
        "success":        True,
        "score":          score,
        "xp_earned":      game.xp_reward,
        "tokens_earned":  total_tokens,
        "token_breakdown": {
            "base": game.token_reward,
            "performance": perf_bonus,
            "bonus": bonus_tokens,
        },
        "total_xp":     request.user.xp,
        "total_tokens": request.user.tokens,
        "level":        request.user.level,
        "my_rank":      rank,
    })


@api_view(["GET", "PATCH"])
def gamer_tag(request):
    """GET or PATCH /api/arcade/gamer-tag/"""
    if request.method == "GET":
        return Response({
            "gamer_tag": request.user.gamer_tag or "",
            "display_name": request.user.display_name,
            "level": request.user.level,
            "xp": request.user.xp,
            "tokens": request.user.tokens,
        })
    tag = request.data.get("gamer_tag", "").strip()
    if len(tag) < 3:
        return Response({"error": "Gamer tag must be at least 3 characters."}, status=400)
    if len(tag) > 20:
        return Response({"error": "Gamer tag max 20 characters."}, status=400)
    if User.objects.filter(gamer_tag__iexact=tag).exclude(id=request.user.id).exists():
        return Response({"error": "That tag is already taken. Pick another!"}, status=400)
    request.user.gamer_tag = tag
    request.user.save(update_fields=["gamer_tag"])
    return Response({"success": True, "gamer_tag": tag})


@api_view(["POST"])
def send_game_request(request):
    try:
        to_user = User.objects.get(user_id=request.data.get("to_user_id"))
        game    = Game.objects.get(slug=request.data.get("game"))
    except (User.DoesNotExist, Game.DoesNotExist) as e:
        return Response({"error": str(e)}, status=404)
    gr = GameRequest.objects.create(from_user=request.user, to_user=to_user, game=game)
    return Response(GameRequestSerializer(gr, context={"request": request}).data,
                    status=status.HTTP_201_CREATED)


@api_view(["GET"])
def my_game_requests(request):
    reqs = GameRequest.objects.filter(
        to_user=request.user, status="pending"
    ).select_related("from_user", "game")
    return Response(GameRequestSerializer(reqs, many=True,
                                         context={"request": request}).data)


@api_view(["POST"])
def respond_game_request(request, req_id):
    try:
        gr = GameRequest.objects.get(id=req_id, to_user=request.user, status="pending")
    except GameRequest.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    action = request.data.get("action")
    if action not in ("accept", "decline"):
        return Response({"error": "action must be accept or decline."}, status=400)
    gr.status = "accepted" if action == "accept" else "declined"
    gr.save(update_fields=["status"])
    return Response({"success": True, "status": gr.status})


@api_view(["GET"])
def player_stats(request):
    scores = GameScore.objects.filter(user=request.user).select_related("game")
    wins   = scores.filter(score__gt=0).count()
    return Response({
        "gamer_tag":   request.user.gamer_tag or "",
        "level":       request.user.level,
        "total_xp":    request.user.xp,
        "tokens":      request.user.tokens,
        "total_games": scores.count(),
        "total_wins":  wins,
        "win_rate":    round((wins / scores.count() * 100) if scores.count() else 0, 1),
        "recent": [
            {
                "game":      s.game.name,
                "game_slug": s.game.slug,
                "score":     s.score,
                "played_at": s.played_at.isoformat(),
            }
            for s in scores.order_by("-played_at")[:10]
        ],
        "best_scores": [
            {
                "game":  row["game__name"],
                "slug":  row["game__slug"],
                "score": row["best"],
            }
            for row in scores.values("game__name", "game__slug")
                              .annotate(best=Max("score"))
                              .order_by("-best")[:7]
        ],
    })