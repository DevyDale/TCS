from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("chat", "0004_alter_message_media_url"),
    ]

    operations = [
        migrations.AddField(
            model_name="roommember",
            name="cleared_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
