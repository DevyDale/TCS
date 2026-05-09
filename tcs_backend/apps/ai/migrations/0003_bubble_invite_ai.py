# apps/chat/migrations/0003_bubbles_invites_ai.py
#
# Adds:
#   • Room.is_public      — distinguishes private (invite-only) from public bubbles
#   • Room.about          — richer description used by chat bubbles
#   • Room.ai_enabled     — whether Dale AI is "in" the room
#   • Message.is_ai       — marks messages authored by Dale
#   • Message.sender → nullable + on_delete=SET_NULL (so AI messages can have null sender,
#     and so messages survive a user account deletion)
#   • RoomInvite          — pending/accepted/declined invitations to a chat bubble
#
# IMPORTANT: update the dependency line below to the actual latest chat migration in
# your repo before running. As of the previous build this is "0002_savedmaterial_subject_source".

import uuid
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("chat", "0002_savedmaterial_subject_source"),
    ]

    operations = [
        # ── Room: bubble + AI fields ──────────────────────────
        migrations.AddField(
            model_name="room",
            name="is_public",
            field=models.BooleanField(default=False, db_index=True),
        ),
        migrations.AddField(
            model_name="room",
            name="about",
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name="room",
            name="ai_enabled",
            field=models.BooleanField(default=False),
        ),

        # ── Message: AI authorship + sender nullable ─────────
        migrations.AddField(
            model_name="message",
            name="is_ai",
            field=models.BooleanField(default=False, db_index=True),
        ),
        migrations.AlterField(
            model_name="message",
            name="sender",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.SET_NULL,
                null=True, blank=True,
                related_name="sent_messages",
                to=settings.AUTH_USER_MODEL,
            ),
        ),

        # ── RoomInvite ────────────────────────────────────────
        migrations.CreateModel(
            name="RoomInvite",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("status", models.CharField(
                    max_length=10,
                    choices=[("pending", "Pending"), ("accepted", "Accepted"), ("declined", "Declined")],
                    default="pending",
                    db_index=True,
                )),
                ("message", models.CharField(max_length=200, blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("responded_at", models.DateTimeField(null=True, blank=True)),
                ("room", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="invites",
                    to="chat.room",
                )),
                ("inviter", models.ForeignKey(
                    on_delete=django.db.models.deletion.SET_NULL,
                    null=True, blank=True,
                    related_name="sent_room_invites",
                    to=settings.AUTH_USER_MODEL,
                )),
                ("invitee", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="received_room_invites",
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                "db_table": "chat_room_invites",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="roominvite",
            index=models.Index(fields=["invitee", "status"], name="invite_user_status_idx"),
        ),
        migrations.AddConstraint(
            model_name="roominvite",
            constraint=models.UniqueConstraint(
                fields=["room", "invitee"],
                condition=models.Q(status="pending"),
                name="unique_pending_invite_per_room_user",
            ),
        ),
    ]