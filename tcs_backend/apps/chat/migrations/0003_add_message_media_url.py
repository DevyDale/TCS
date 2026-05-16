from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('chat', '0002_roominvite_message_is_ai_room_about_room_ai_enabled_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='message',
            name='media_url',
            field=models.URLField(blank=True, default='', max_length=500),
        ),
    ]
