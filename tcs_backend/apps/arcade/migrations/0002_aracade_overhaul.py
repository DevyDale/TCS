# apps/arcade/migrations/0002_arcade_overhaul.py
import uuid
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("arcade", "0001_initial"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # ── Game: invite_mode + streamable ────────────────────
        migrations.AddField(
            model_name="game",
            name="invite_mode",
            field=models.CharField(
                choices=[
                    ("solo_only",  "Solo only (no challenges)"),
                    ("first_come", "First-come duel (1v1, multi-invite OK)"),
                    ("royale",     "Battle royale (everyone who accepts joins)"),
                ],
                default="first_come",
                max_length=15,
            ),
        ),
        migrations.AddField(
            model_name="game",
            name="streamable",
            field=models.BooleanField(default=True),
        ),

        # ── GameInvite ────────────────────────────────────────
        migrations.CreateModel(
            name="GameInvite",
            fields=[
                ("id",          models.UUIDField(default=uuid.uuid4, editable=False,
                                                 primary_key=True, serialize=False)),
                ("wager",       models.PositiveIntegerField(default=0)),
                ("invite_mode", models.CharField(max_length=15)),
                ("status",      models.CharField(
                    choices=[
                        ("pending",   "Pending"),
                        ("started",   "Started"),
                        ("completed", "Completed"),
                        ("expired",   "Expired"),
                        ("cancelled", "Cancelled"),
                    ],
                    default="pending", max_length=20)),
                ("created_at",  models.DateTimeField(auto_now_add=True)),
                ("expires_at",  models.DateTimeField()),
                ("game",        models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="invites", to="arcade.game")),
                ("sender",      models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="sent_invites", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "game_invites",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="gameinvite",
            index=models.Index(fields=["sender", "status"],
                               name="game_invite_sender_status_idx"),
        ),
        migrations.AddIndex(
            model_name="gameinvite",
            index=models.Index(fields=["status", "expires_at"],
                               name="game_invite_status_exp_idx"),
        ),

        # ── GameRequest: invite FK + paid + responded_at ──────
        migrations.AddField(
            model_name="gamerequest",
            name="invite",
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="requests", to="arcade.gameinvite"),
        ),
        migrations.AddField(
            model_name="gamerequest",
            name="paid",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="gamerequest",
            name="responded_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        # Add the auto_declined status by altering choices
        migrations.AlterField(
            model_name="gamerequest",
            name="status",
            field=models.CharField(
                choices=[
                    ("pending",       "Pending"),
                    ("accepted",      "Accepted"),
                    ("declined",      "Declined"),
                    ("expired",       "Expired"),
                    ("auto_declined", "Auto-Declined"),
                ],
                default="pending", max_length=20),
        ),

        # ── GameSession: invite FK + new lifecycle fields ─────
        migrations.AddField(
            model_name="gamesession",
            name="invite",
            field=models.OneToOneField(
                blank=True, null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="session", to="arcade.gameinvite"),
        ),
        migrations.AddField(
            model_name="gamesession",
            name="game",
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name="sessions", to="arcade.game"),
        ),
        migrations.AddField(
            model_name="gamesession",
            name="pot",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="gamesession",
            name="spectator_count",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="gamesession",
            name="started_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="gamesession",
            name="ended_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        # Make request nullable since new sessions use invite
        migrations.AlterField(
            model_name="gamesession",
            name="request",
            field=models.OneToOneField(
                blank=True, null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="session", to="arcade.gamerequest"),
        ),
        migrations.AlterField(
            model_name="gamesession",
            name="player1",
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="p1_sessions", to=settings.AUTH_USER_MODEL),
        ),
        migrations.AlterField(
            model_name="gamesession",
            name="player2",
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="p2_sessions", to=settings.AUTH_USER_MODEL),
        ),
        migrations.AlterField(
            model_name="gamesession",
            name="status",
            field=models.CharField(
                choices=[
                    ("waiting",   "Waiting for players"),
                    ("active",    "Active"),
                    ("completed", "Completed"),
                    ("abandoned", "Abandoned"),
                ],
                default="waiting", max_length=20),
        ),
        migrations.AddIndex(
            model_name="gamesession",
            index=models.Index(fields=["status", "-created_at"],
                               name="game_session_status_idx"),
        ),
        migrations.AddIndex(
            model_name="gamesession",
            index=models.Index(fields=["game_slug", "status"],
                               name="game_session_slug_idx"),
        ),

        # ── SessionPlayer ─────────────────────────────────────
        migrations.CreateModel(
            name="SessionPlayer",
            fields=[
                ("id",          models.BigAutoField(auto_created=True,
                                                    primary_key=True, serialize=False)),
                ("wager_paid",  models.PositiveIntegerField(default=0)),
                ("score",       models.IntegerField(default=0)),
                ("placement",   models.PositiveSmallIntegerField(default=0)),
                ("forfeited",   models.BooleanField(default=False)),
                ("joined_at",   models.DateTimeField(auto_now_add=True)),
                ("finished_at", models.DateTimeField(blank=True, null=True)),
                ("session",     models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="participants", to="arcade.gamesession")),
                ("user",        models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="session_seats", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "game_session_players",
                "unique_together": {("session", "user")},
            },
        ),

        # ── TokenLedger ───────────────────────────────────────
        migrations.CreateModel(
            name="TokenLedger",
            fields=[
                ("id",             models.BigAutoField(auto_created=True,
                                                       primary_key=True, serialize=False)),
                ("delta",          models.IntegerField()),
                ("balance_after",  models.IntegerField()),
                ("reason",         models.CharField(
                    choices=[
                        ("solo_win",      "Solo Game Reward"),
                        ("match_win",     "Match Win Payout"),
                        ("wager_escrow",  "Wager Escrowed"),
                        ("wager_refund",  "Wager Refunded"),
                        ("transfer_in",   "Transfer Received"),
                        ("transfer_out",  "Transfer Sent"),
                        ("daily_stipend", "Daily Login Stipend"),
                        ("signup_bonus",  "Signup Bonus"),
                        ("admin_grant",   "Admin Grant"),
                        ("admin_deduct",  "Admin Deduct"),
                    ], max_length=20)),
                ("reference_type", models.CharField(blank=True, max_length=40)),
                ("reference_id",   models.CharField(blank=True, max_length=64)),
                ("note",           models.CharField(blank=True, max_length=140)),
                ("created_at",     models.DateTimeField(auto_now_add=True)),
                ("user",           models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="token_ledger", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "token_ledger",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="tokenledger",
            index=models.Index(fields=["user", "-created_at"],
                               name="ledger_user_time_idx"),
        ),
        migrations.AddIndex(
            model_name="tokenledger",
            index=models.Index(fields=["reference_type", "reference_id"],
                               name="ledger_ref_idx"),
        ),

        # ── TokenTransfer ─────────────────────────────────────
        migrations.CreateModel(
            name="TokenTransfer",
            fields=[
                ("id",         models.UUIDField(default=uuid.uuid4, editable=False,
                                                primary_key=True, serialize=False)),
                ("amount",     models.PositiveIntegerField()),
                ("note",       models.CharField(blank=True, max_length=140)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("recipient",  models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="received_transfers", to=settings.AUTH_USER_MODEL)),
                ("sender",     models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="sent_transfers", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "token_transfers",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="tokentransfer",
            index=models.Index(fields=["sender", "-created_at"],
                               name="transfer_sender_idx"),
        ),
        migrations.AddIndex(
            model_name="tokentransfer",
            index=models.Index(fields=["recipient", "-created_at"],
                               name="transfer_recipient_idx"),
        ),

        # ── MatchMessage ──────────────────────────────────────
        migrations.CreateModel(
            name="MatchMessage",
            fields=[
                ("id",         models.BigAutoField(auto_created=True,
                                                   primary_key=True, serialize=False)),
                ("kind",       models.CharField(
                    choices=[("cheer", "Cheer"), ("message", "Message")],
                    default="message", max_length=10)),
                ("text",       models.CharField(blank=True, max_length=120)),
                ("emoji",      models.CharField(blank=True, max_length=8)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("session",    models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="match_messages", to="arcade.gamesession")),
                ("user",       models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "match_messages",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="matchmessage",
            index=models.Index(fields=["session", "-created_at"],
                               name="match_msg_session_idx"),
        ),
    ]