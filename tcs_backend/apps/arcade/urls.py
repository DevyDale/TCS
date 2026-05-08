# apps/arcade/urls.py
from django.urls import path
from . import views

urlpatterns = [
    # Catalog + leaderboards
    path("games/",                  views.game_list,        name="game-list"),
    path("leaderboard/",            views.leaderboard,      name="leaderboard"),
    path("stats/",                  views.player_stats,     name="player-stats"),

    # Wallet
    path("tokens/",                 views.token_wallet,     name="token-wallet"),
    path("tokens/history/",         views.token_history,    name="token-history"),
    path("tokens/transfers/",       views.transfer_history, name="transfer-history"),
    path("tokens/transfer/",        views.transfer_tokens,  name="transfer-tokens"),

    # Solo score
    path("submit-score/",           views.submit_score,     name="submit-score"),

    # Gamer tag
    path("gamer-tag/",              views.gamer_tag,        name="gamer-tag"),
    path("gamer-tag/search/",       views.gamer_search,     name="gamer-search"),

    # Invites & requests (multiplayer)
    path("game-requests/",                          views.my_game_requests,
         name="game-requests"),
    path("game-invites/",                           views.create_invite,
         name="create-invite"),
    path("game-invites/sent/",                      views.my_sent_invites,
         name="sent-invites"),
    path("game-invites/<uuid:invite_id>/cancel/",   views.cancel_invite_view,
         name="cancel-invite"),
    path("game-requests/<uuid:req_id>/accept/",     views.accept_request,
         name="accept-request"),
    path("game-requests/<uuid:req_id>/decline/",    views.decline_request,
         name="decline-request"),

    # Sessions
    path("sessions/live/",                          views.live_sessions,
         name="live-sessions"),
    path("sessions/<uuid:session_id>/",             views.session_detail,
         name="session-detail"),
    path("sessions/<uuid:session_id>/start/",       views.start_session,
         name="session-start"),
    path("sessions/<uuid:session_id>/result/",      views.submit_match_result,
         name="session-result"),
    path("sessions/<uuid:session_id>/forfeit/",     views.forfeit_session,
         name="session-forfeit"),
    path("sessions/<uuid:session_id>/messages/",    views.match_messages,
         name="match-messages"),
]