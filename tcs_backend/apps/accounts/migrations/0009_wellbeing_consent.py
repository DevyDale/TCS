from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0008_user_is_safeguarding_lead"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="wellbeing_opt_out",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="user",
            name="wellbeing_notice_seen_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
