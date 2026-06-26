from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0006_user_suspend"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="is_fire_warden",
            field=models.BooleanField(default=False),
        ),
    ]
