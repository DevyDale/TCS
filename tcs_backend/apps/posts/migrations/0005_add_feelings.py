# apps/posts/migrations/0005_add_feelings.py
#
# Creates the Feeling lookup table, adds a nullable FK on Post, and
# seeds 20 starter feelings spread across mood / activity / state.
# Idempotent — uses update_or_create so re-running this migration
# (e.g. after a dev DB reset) won't create duplicates.

from django.db import migrations, models
import django.db.models.deletion


# ─────────────────────────────────────────────────────────────
# SEED DATA
# ─────────────────────────────────────────────────────────────
# (slug, label, emoji, category, sort_order)
SEED_FEELINGS = [
    # Mood (10–100)
    ("happy",        "happy",        "😊", "mood",     10),
    ("excited",      "excited",      "🤩", "mood",     20),
    ("grateful",     "grateful",     "🥰", "mood",     30),
    ("celebrating",  "celebrating",  "🥳", "mood",     40),
    ("in_love",      "in love",      "😍", "mood",     50),
    ("cool",         "cool",         "😎", "mood",     60),
    ("chill",        "chill",        "😌", "mood",     70),
    ("sad",          "sad",          "😢", "mood",     80),
    ("frustrated",   "frustrated",   "😤", "mood",     90),
    ("overwhelmed",  "overwhelmed",  "😭", "mood",    100),

    # Activity (110–160)
    ("studying",     "studying",     "📚", "activity", 110),
    ("motivated",    "motivated",    "💪", "activity", 120),
    ("productive",   "productive",   "🤓", "activity", 130),
    ("partying",     "partying",     "🎉", "activity", 140),
    ("traveling",    "traveling",    "✈️", "activity", 150),
    ("vibing",       "vibing",       "🎵", "activity", 160),

    # State (170–200)
    ("hungry",       "hungry",       "🍕", "state",    170),
    ("caffeinated",  "caffeinated",  "☕", "state",    180),
    ("tired",        "tired",        "😴", "state",    190),
    ("sick",         "sick",         "🤒", "state",    200),
]


def seed_feelings(apps, schema_editor):
    """Insert (or update) the starter feelings."""
    Feeling = apps.get_model("posts", "Feeling")
    for slug, label, emoji, category, sort_order in SEED_FEELINGS:
        Feeling.objects.update_or_create(
            slug=slug,
            defaults={
                "label":      label,
                "emoji":      emoji,
                "category":   category,
                "sort_order": sort_order,
                "is_active":  True,
            },
        )


def unseed_feelings(apps, schema_editor):
    """Reverse: clear the seeded rows. Used if migration is rolled back."""
    Feeling = apps.get_model("posts", "Feeling")
    Feeling.objects.filter(
        slug__in=[s[0] for s in SEED_FEELINGS]
    ).delete()


# ─────────────────────────────────────────────────────────────
# MIGRATION
# ─────────────────────────────────────────────────────────────

class Migration(migrations.Migration):

    dependencies = [
        ("posts", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="Feeling",
            fields=[
                ("id", models.BigAutoField(
                    auto_created=True, primary_key=True, serialize=False)),
                ("slug", models.SlugField(
                    max_length=40, unique=True, db_index=True)),
                ("label", models.CharField(max_length=40)),
                ("emoji", models.CharField(max_length=8)),
                ("category", models.CharField(blank=True, max_length=20)),
                ("sort_order", models.PositiveSmallIntegerField(default=0)),
                ("is_active", models.BooleanField(default=True)),
            ],
            options={
                "db_table": "feelings",
                "ordering": ["sort_order", "label"],
            },
        ),
        migrations.AddField(
            model_name="post",
            name="feeling",
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="posts",
                to="posts.feeling",
            ),
        ),
        migrations.RunPython(seed_feelings, unseed_feelings),
    ]