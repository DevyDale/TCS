from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("notifications", "0001_initial")]

    operations = [
        migrations.AlterField(
            model_name="notification",
            name="notif_type",
            field=models.CharField(
                max_length=30,
                choices=[
                    ("like", "Like"),
                    ("comment", "Comment"),
                    ("follow", "Follow"),
                    ("mention", "Mention"),
                    ("chat_message", "Chat Message"),
                    ("chat_request", "Chat Request"),
                    ("game_request", "Game Request"),
                    ("event_reminder", "Event Reminder"),
                    ("highlight", "New Highlight"),
                    ("study_buddy_request", "Study Buddy Request"),
                    ("study_group_invite", "Study Group Invite"),
                    ("achievement", "Achievement"),
                    ("system", "System"),
                ],
            ),
        ),
    ]