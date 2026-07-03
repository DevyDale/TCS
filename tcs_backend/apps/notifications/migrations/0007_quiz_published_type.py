from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("notifications", "0006_announcement_image_url"),
    ]

    operations = [
        migrations.AlterField(
            model_name="notification",
            name="notif_type",
            field=models.CharField(
                choices=[
                    ("like", "Like"),
                    ("comment", "Comment"),
                    ("follow", "Follow"),
                    ("mention", "Mention"),
                    ("chat_message", "Chat Message"),
                    ("chat_request", "Chat Request"),
                    ("request_accepted", "Request Accepted"),
                    ("request_declined", "Request Declined"),
                    ("group_add", "Added to Group"),
                    ("group_message", "Group Message"),
                    ("group_material", "Group Material"),
                    ("club_event", "Club Event"),
                    ("game_request", "Game Request"),
                    ("event_reminder", "Event Reminder"),
                    ("quiz_published", "Quiz Published"),
                    ("achievement", "Achievement"),
                    ("announcement", "Announcement"),
                    ("system", "System"),
                    ("birthday", "Birthday"),
                ],
                max_length=20,
            ),
        ),
    ]
