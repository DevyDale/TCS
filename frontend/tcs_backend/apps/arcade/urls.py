# apps/arcade/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path("games/",              views.game_list,            name="game-list"),
    path("leaderboard/",        views.leaderboard,          name="leaderboard"),
    path("stats/",              views.player_stats,         name="player-stats"),
    path("tokens/",             views.token_wallet,         name="token-wallet"),
    path("submit-score/",       views.submit_score,         name="submit-score"),
    path("gamer-tag/",          views.gamer_tag,            name="gamer-tag"),
    path("game-requests/",      views.my_game_requests,     name="game-requests"),
    path("game-requests/send/", views.send_game_request,    name="send-game-request"),
    path("game-requests/<uuid:req_id>/respond/",views.respond_game_request, name="respond-game-request"),
]