from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0007_user_is_fire_warden"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="is_safeguarding_lead",
            field=models.BooleanField(default=False),
        ),
    ]
