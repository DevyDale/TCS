from django.core.management.base import BaseCommand
from apps.arcade.models import Game

GAMES = [
    {"name": "Quiz Battle",     "slug": "quiz-battle",     "description": "Fast-paced trivia — answer questions across Science, History, Pop Culture and more.",
     "category": "trivia",      "xp_reward": 100, "token_reward": 12, "is_featured": True,  "min_players": 1, "max_players": 4},
    {"name": "Tic Tac Toe",     "slug": "tic-tac-toe",     "description": "Classic X vs O. Beat the AI or challenge a friend — three in a row wins.",
     "category": "strategy",    "xp_reward": 40,  "token_reward": 5,  "is_featured": False, "min_players": 1, "max_players": 2},
    {"name": "Memory Match",    "slug": "memory-match",    "description": "Flip cards and match pairs. Fewest flips = biggest score.",
     "category": "puzzle",      "xp_reward": 60,  "token_reward": 8,  "is_featured": False, "min_players": 1, "max_players": 1},
    {"name": "Snake",           "slug": "snake",            "description": "Guide the neon serpent through the server room — eat data nodes, avoid your tail.",
     "category": "action",      "xp_reward": 75,  "token_reward": 9,  "is_featured": False, "min_players": 1, "max_players": 1},
    {"name": "Number Guesser",  "slug": "number-guesser",  "description": "Crack the hidden number with Higher / Lower hints. Fewer guesses = more points.",
     "category": "puzzle",      "xp_reward": 30,  "token_reward": 4,  "is_featured": False, "min_players": 1, "max_players": 1},
    {"name": "Spirit Racers",   "slug": "spirit-racers",   "description": "Dodge rival ghost cars and collect coins in this neon campus kart racer.",
     "category": "racing",      "xp_reward": 95,  "token_reward": 12, "is_featured": True,  "min_players": 1, "max_players": 1},
    {"name": "Ninja Tag",       "slug": "ninja-tag",       "description": "Slip through the grid, collect stars, and evade shadow phantoms before time runs out.",
     "category": "action",      "xp_reward": 90,  "token_reward": 10, "is_featured": True,  "min_players": 1, "max_players": 1},
    {"name": "Sushi Rush",      "slug": "sushi-rush",      "description": "Memorise the sushi order and tap them back in the exact sequence — beat the clock!",
     "category": "puzzle",      "xp_reward": 80,  "token_reward": 10, "is_featured": False, "min_players": 1, "max_players": 1},
    {"name": "Battle Bots",     "slug": "battle-bots",     "description": "Turn-based robot strategy — move, attack, and destroy all enemy bots to win.",
     "category": "strategy",    "xp_reward": 110, "token_reward": 14, "is_featured": False, "min_players": 1, "max_players": 2},
    {"name": "Campus Craft",    "slug": "campus-craft",    "description": "Slide the scrambled campus blueprint tiles back into order in the fewest moves.",
     "category": "puzzle",      "xp_reward": 120, "token_reward": 15, "is_featured": True,  "min_players": 1, "max_players": 1},
    {"name": "Pool Royale",     "slug": "pool-royale",     "description": "Physics billiards — drag to aim, release to shoot, pocket all balls to win.",
     "category": "sports",      "xp_reward": 70,  "token_reward": 8,  "is_featured": False, "min_players": 1, "max_players": 2},
    {"name": "Stickman Hoops",  "slug": "basketball",      "description": "Launch the basketball in a perfect arc through the hoop — wind and distance increase each level.",
     "category": "sports",      "xp_reward": 85,  "token_reward": 10, "is_featured": True,  "min_players": 1, "max_players": 1},
    {"name": "Texas Hold'em",   "slug": "texas-poker",     "description": "Campus poker night — fold, call or raise your way to the pot against cunning AI opponents.",
     "category": "strategy",    "xp_reward": 130, "token_reward": 18, "is_featured": True,  "min_players": 1, "max_players": 4},
]


class Command(BaseCommand):
    help = "Seed all arcade games (13 total)"

    def handle(self, *args, **options):
        created = updated = 0
        for data in GAMES:
            slug = data.pop("slug")
            obj, ok = Game.objects.update_or_create(slug=slug, defaults=data)
            data["slug"] = slug  # restore for logging
            if ok:
                created += 1
                self.stdout.write(self.style.SUCCESS(f"  ✓ {obj.name}"))
            else:
                updated += 1
                self.stdout.write(f"  ↺ {obj.name} (updated)")
        self.stdout.write(self.style.SUCCESS(
            f"\nDone. {created} created, {updated} updated. {len(GAMES)} total games."))