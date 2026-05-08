# apps/arcade/views.py
#
# Endpoints (all under /api/arcade/):
#   GET   games/                          — list games
#   GET   leaderboard/                    — global / per-game leaderboard
#   GET   stats/                          — current user's stats
#   GET   tokens/                         — wallet balance
#   GET   tokens/history/                 — wallet ledger
#   GET   tokens/transfers/               — peer transfer history
#   POST  tokens/transfer/                — peer-to-peer send
#   GET   gamer-tag/                      — get tag
#   PATCH gamer-tag/                      — set tag
#   GET   gamer-tag/search/               — search by tag prefix
#   POST  submit-score/                   — solo score submission
#
#   GET   game-requests/                  — my INCOMING pending requests
#   GET   game-invites/sent/              — my SENT invites (any status)
#   POST  game-invites/                   — create an invite (1..4 recipients)
#   POST  game-invites/<id>/cancel/       — sender cancels
#   POST  game-requests/<id>/accept/      — recipient accepts
#   POST  game-requests/<id>/decline/     — recipient declines
#
#   GET   sessions/live/                  — currently-active sessions
#   GET   sessions/<id>/                  — session detail
#   POST  sessions/<id>/start/            — players signal "go"
#   POST  sessions/<id>/result/           — player submits their final score
#   POST  sessions/<id>/forfeit/          — player forfeits

from django.contrib.auth import get_user_model
from django.db           import transaction
from django.db.models    import Max, Count, Q, Sum
from django.utils        import timezone
from rest_framework      import status as drf_status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response   import Response

from . import services
from .models import (
    Game, GameScore, GameInvite, GameRequest, GameSession,
    SessionPlayer, TokenLedger, TokenTransfer, MatchMessage,
)
from .serializers import (
    GameSerializer, GameInviteSerializer, GameRequestSerializer,
    GameSessionSerializer, TokenLedgerSerializer,
    TokenTransferSerializer, MatchMessageSerializer,
)

User = get_user_model()


# ─────────────────────────────────────────────────────────────
# Games
# ─────────────────────────────────────────────────────────────
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def game_list(request):
    games = Game.objects.filter(is_active=True).order_by("-is_featured", "-play_count")
    return Response(GameSerializer(games, many=True,
                                   context={"request": request}).data)


# ─────────────────────────────────────────────────────────────
# Leaderboard
# ─────────────────────────────────────────────────────────────
@api_view(["GET"])
@permission_classes([IsAuthenticated])
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


# ─────────────────────────────────────────────────────────────
# Stats
# ─────────────────────────────────────────────────────────────
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def player_stats(request):
    u      = request.user
    scores = GameScore.objects.filter(user=u).select_related("game")
    wins   = SessionPlayer.objects.filter(user=u, placement=1,
                                          session__status="completed").count()
    losses = SessionPlayer.objects.filter(user=u, session__status="completed"
                                          ).exclude(placement=1).count()
    return Response({
        "gamer_tag":   u.gamer_tag or "",
        "level":       u.level,
        "total_xp":    u.xp,
        "tokens":      u.tokens,
        "total_games": scores.count(),
        "total_wins":  wins,
        "total_losses": losses,
        "win_rate":    round((wins / (wins + losses) * 100) if (wins + losses) else 0, 1),
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


# ─────────────────────────────────────────────────────────────
# Wallet
# ─────────────────────────────────────────────────────────────
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def token_wallet(request):
    return Response({
        "tokens":    request.user.tokens,
        "level":     request.user.level,
        "xp":        request.user.xp,
        "gamer_tag": request.user.gamer_tag or "",
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def token_history(request):
    """Wallet ledger (most recent first)."""
    limit = min(int(request.query_params.get("limit", 50)), 200)
    rows  = TokenLedger.objects.filter(user=request.user)[:limit]
    return Response(TokenLedgerSerializer(rows, many=True).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def transfer_history(request):
    """Peer-to-peer transfer history (sent and received)."""
    limit = min(int(request.query_params.get("limit", 50)), 200)
    rows  = (TokenTransfer.objects
             .filter(Q(sender=request.user) | Q(recipient=request.user))
             .select_related("sender", "recipient")[:limit])
    return Response(TokenTransferSerializer(rows, many=True,
                                            context={"request": request}).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def transfer_tokens(request):
    """Send tokens to another user. Body: {recipient_user_id, amount, note}."""
    rid    = (request.data.get("recipient_user_id") or "").strip()
    amount = request.data.get("amount", 0)
    note   = (request.data.get("note") or "").strip()
    try:
        amount = int(amount)
    except (TypeError, ValueError):
        return Response({"error": "Invalid amount."}, status=400)
    if not rid:
        return Response({"error": "Recipient required."}, status=400)
    try:
        recipient = User.objects.get(user_id=rid, is_active=True)
    except User.DoesNotExist:
        return Response({"error": "Recipient not found."}, status=404)

    try:
        tx = services.transfer(request.user, recipient, amount, note)
    except services.InsufficientTokens as e:
        return Response({"error": str(e)}, status=400)
    except services.TransferLimitExceeded as e:
        return Response({"error": str(e)}, status=400)
    except (services.InvalidRecipient, ValueError) as e:
        return Response({"error": str(e)}, status=400)

    return Response({
        "success":     True,
        "transfer_id": str(tx.id),
        "amount":      tx.amount,
        "balance":     request.user.tokens,
        "recipient":   {
            "user_id":      recipient.user_id,
            "gamer_tag":    recipient.gamer_tag or "",
            "display_name": recipient.display_name,
        },
    }, status=drf_status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────
# Solo score submission (existing single-player flow)
# ─────────────────────────────────────────────────────────────
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def submit_score(request):
    slug         = request.data.get("game", "")
    score        = max(0, int(request.data.get("score", 0)))
    bonus_tokens = int(request.data.get("bonus_tokens", 0))

    try:
        game = Game.objects.get(slug=slug, is_active=True)
    except Game.DoesNotExist:
        return Response({"error": "Game not found."}, status=404)

    GameScore.objects.create(game=game, user=request.user, score=score)
    Game.objects.filter(pk=game.pk).update(play_count=game.play_count + 1)
    request.user.add_xp(game.xp_reward)

    payout = services.solo_reward(request.user, game, score, bonus_tokens)
    rank = (
        GameScore.objects.filter(game=game, score__gt=score)
        .values("user").distinct().count() + 1
    )
    return Response({
        "success":         True,
        "score":           score,
        "xp_earned":       game.xp_reward,
        "tokens_earned":   payout["tokens_earned"],
        "token_breakdown": payout["breakdown"],
        "total_xp":        request.user.xp,
        "total_tokens":    request.user.tokens,
        "level":           request.user.level,
        "my_rank":         rank,
    })


# ─────────────────────────────────────────────────────────────
# Gamer tag
# ─────────────────────────────────────────────────────────────
@api_view(["GET", "PATCH"])
@permission_classes([IsAuthenticated])
def gamer_tag(request):
    if request.method == "GET":
        return Response({
            "gamer_tag":    request.user.gamer_tag or "",
            "display_name": request.user.display_name,
            "level":        request.user.level,
            "xp":           request.user.xp,
            "tokens":       request.user.tokens,
        })
    tag = (request.data.get("gamer_tag") or "").strip()
    if len(tag) < 3:
        return Response({"error": "Gamer tag must be at least 3 characters."}, status=400)
    if len(tag) > 20:
        return Response({"error": "Gamer tag max 20 characters."}, status=400)
    if User.objects.filter(gamer_tag__iexact=tag).exclude(id=request.user.id).exists():
        return Response({"error": "That tag is already taken. Pick another!"}, status=400)
    request.user.gamer_tag = tag
    request.user.save(update_fields=["gamer_tag"])
    return Response({"success": True, "gamer_tag": tag})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def gamer_search(request):
    """GET /arcade/gamer-tag/search/?q=ash — typeahead by gamer_tag prefix."""
    q     = (request.query_params.get("q") or "").strip()
    limit = min(int(request.query_params.get("limit", 10)), 30)
    if len(q) < 1:
        return Response({"results": []})

    qs = (User.objects.filter(is_active=True)
          .filter(Q(gamer_tag__istartswith=q) |
                  Q(preferred_name__istartswith=q) |
                  Q(name__istartswith=q))
          .exclude(pk=request.user.pk)
          .exclude(gamer_tag="")[:limit])

    results = []
    for u in qs:
        avatar = None
        if u.avatar:
            try:
                avatar = (request.build_absolute_uri(u.avatar.url)
                          if request else u.avatar.url)
            except Exception:
                avatar = None
        results.append({
            "user_id":      u.user_id,
            "gamer_tag":    u.gamer_tag or "",
            "display_name": u.display_name,
            "avatar_url":   avatar,
            "level":        u.level,
            "is_online":    u.is_online,
        })
    return Response({"results": results})


# ─────────────────────────────────────────────────────────────
# Incoming requests for me
# ─────────────────────────────────────────────────────────────
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def my_game_requests(request):
    """Pending challenges where I'm the receiver."""
    services.expire_stale_invites()  # opportunistic cleanup
    qs = (GameRequest.objects
          .filter(receiver=request.user, status="pending")
          .select_related("sender", "invite", "invite__game")
          .order_by("-created_at"))
    return Response(GameRequestSerializer(qs, many=True,
                                          context={"request": request}).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def my_sent_invites(request):
    """Invites I've sent (any status)."""
    services.expire_stale_invites()
    status_filter = request.query_params.get("status")
    qs = (GameInvite.objects.filter(sender=request.user)
          .select_related("sender", "game")
          .prefetch_related("requests__receiver"))
    if status_filter:
        qs = qs.filter(status=status_filter)
    qs = qs.order_by("-created_at")[:50]
    return Response(GameInviteSerializer(qs, many=True,
                                         context={"request": request}).data)


# ─────────────────────────────────────────────────────────────
# Create an invite
# ─────────────────────────────────────────────────────────────
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def create_invite(request):
    """Body:
        {
          "game_slug":           "pool-royale",
          "wager":                50,
          "recipient_user_ids": ["S001", "S002", ...]    // 1..4
        }
    Backwards-compatible: also accepts single `receiver_id` + `game_slug`.
    """
    data       = request.data
    slug       = (data.get("game_slug") or data.get("game") or "").strip()
    wager      = int(data.get("wager") or 0)
    rid_list   = data.get("recipient_user_ids") or []
    single_rid = data.get("receiver_id")
    if single_rid and not rid_list:
        rid_list = [single_rid]

    if not slug:
        return Response({"error": "game_slug required."}, status=400)
    try:
        game = Game.objects.get(slug=slug, is_active=True)
    except Game.DoesNotExist:
        return Response({"error": "Game not found."}, status=404)
    if not rid_list:
        return Response({"error": "At least one recipient required."}, status=400)

    recipients = list(User.objects.filter(user_id__in=rid_list, is_active=True))
    if len(recipients) != len(set(rid_list)):
        return Response({"error": "One or more recipients not found."}, status=404)

    try:
        invite, _reqs = services.create_invite(request.user, game, wager, recipients)
    except services.InsufficientTokens as e:
        return Response({"error": str(e)}, status=400)
    except (services.InvalidRecipient, ValueError) as e:
        return Response({"error": str(e)}, status=400)

    return Response(GameInviteSerializer(invite, context={"request": request}).data,
                    status=drf_status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────
# Accept / Decline / Cancel
# ─────────────────────────────────────────────────────────────
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def accept_request(request, req_id):
    try:
        gr = GameRequest.objects.select_related("invite", "invite__game",
                                                "receiver").get(pk=req_id)
    except GameRequest.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    try:
        session = services.accept_request(gr, request.user)
    except services.InsufficientTokens as e:
        return Response({"error": str(e)}, status=400)
    except (PermissionError, ValueError) as e:
        return Response({"error": str(e)}, status=400)

    return Response({
        "success": True,
        "session": GameSessionSerializer(session, context={"request": request}).data,
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def decline_request(request, req_id):
    try:
        gr = GameRequest.objects.select_related("invite").get(pk=req_id)
    except GameRequest.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    try:
        services.decline_request(gr, request.user)
    except (PermissionError, ValueError) as e:
        return Response({"error": str(e)}, status=400)
    return Response({"success": True, "status": "declined"})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def cancel_invite_view(request, invite_id):
    try:
        inv = GameInvite.objects.get(pk=invite_id)
    except GameInvite.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    try:
        services.cancel_invite(inv, request.user)
    except (PermissionError, ValueError) as e:
        return Response({"error": str(e)}, status=400)
    return Response({"success": True, "status": "cancelled"})


# ─────────────────────────────────────────────────────────────
# Sessions
# ─────────────────────────────────────────────────────────────
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def live_sessions(request):
    """Currently-active sessions (anyone can spectate)."""
    qs = (GameSession.objects
          .filter(status="active")
          .select_related("game", "player1", "player2", "winner", "invite")
          .prefetch_related("participants__user")
          .order_by("-started_at")[:50])
    return Response(GameSessionSerializer(qs, many=True,
                                          context={"request": request}).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def session_detail(request, session_id):
    try:
        sess = (GameSession.objects.select_related("game", "winner", "invite")
                .prefetch_related("participants__user").get(pk=session_id))
    except GameSession.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    return Response(GameSessionSerializer(sess, context={"request": request}).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def start_session(request, session_id):
    """Both players signal ready → flip to active."""
    try:
        sess = GameSession.objects.get(pk=session_id)
    except GameSession.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    if not sess.participants.filter(user=request.user).exists():
        return Response({"error": "Not in this session."}, status=403)
    if sess.status == "waiting":
        sess.status     = "active"
        sess.started_at = timezone.now()
        sess.save(update_fields=["status", "started_at"])
    return Response({"success": True, "status": sess.status})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def submit_match_result(request, session_id):
    """A player reports their final score for this match.

    The session is settled once every non-forfeited participant has
    submitted (or the timeout expires — handled separately).

    Body: { "score": 1234 }
    """
    score = max(0, int(request.data.get("score", 0)))
    try:
        sess = GameSession.objects.select_related("invite", "game").get(pk=session_id)
    except GameSession.DoesNotExist:
        return Response({"error": "Not found."}, status=404)

    sp = sess.participants.filter(user=request.user).first()
    if sp is None:
        return Response({"error": "Not in this session."}, status=403)
    if sess.status == "completed":
        return Response({"error": "Session already settled."}, status=400)

    sp.score        = score
    sp.finished_at  = timezone.now()
    sp.save(update_fields=["score", "finished_at"])

    # If everyone has finished (or forfeited), settle.
    pending = sess.participants.filter(finished_at__isnull=True,
                                       forfeited=False).exists()
    if not pending:
        scores = {p.user_id: p.score for p in sess.participants.all()}
        forfeited = [p.user_id for p in sess.participants.all() if p.forfeited]
        try:
            payout = services.settle_match(sess, scores, forfeited_by=forfeited)
        except services.MatchAlreadySettled:
            pass
        else:
            sess.refresh_from_db()
            return Response({
                "success":  True,
                "settled":  True,
                "session":  GameSessionSerializer(sess,
                                context={"request": request}).data,
                "payout":   payout,
                "balance":  request.user.tokens,
            })

    return Response({
        "success":  True,
        "settled":  False,
        "session":  GameSessionSerializer(sess,
                        context={"request": request}).data,
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def forfeit_session(request, session_id):
    try:
        sess = GameSession.objects.get(pk=session_id)
    except GameSession.DoesNotExist:
        return Response({"error": "Not found."}, status=404)
    sp = sess.participants.filter(user=request.user).first()
    if sp is None:
        return Response({"error": "Not in this session."}, status=403)
    if sess.status == "completed":
        return Response({"error": "Already finished."}, status=400)

    with transaction.atomic():
        sp.forfeited   = True
        sp.finished_at = timezone.now()
        sp.score       = 0
        sp.save(update_fields=["forfeited", "finished_at", "score"])

    # If only one player remains, settle now in their favour
    pending = sess.participants.filter(finished_at__isnull=True,
                                       forfeited=False).count()
    if pending <= 1:
        scores    = {p.user_id: p.score for p in sess.participants.all()}
        forfeited = [p.user_id for p in sess.participants.all() if p.forfeited]
        try:
            services.settle_match(sess, scores, forfeited_by=forfeited)
        except services.MatchAlreadySettled:
            pass

    sess.refresh_from_db()
    return Response({
        "success": True,
        "session": GameSessionSerializer(sess, context={"request": request}).data,
    })


# ─────────────────────────────────────────────────────────────
# Match messages (cheers/comments) — REST fallback for fetching
# the recent stream when joining as a spectator. The realtime
# delivery is via the WebSocket consumer.
# ─────────────────────────────────────────────────────────────
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def match_messages(request, session_id):
    limit = min(int(request.query_params.get("limit", 30)), 100)
    rows  = (MatchMessage.objects.filter(session_id=session_id)
             .select_related("user")
             .order_by("-created_at")[:limit])
    return Response(MatchMessageSerializer(reversed(list(rows)), many=True).data)