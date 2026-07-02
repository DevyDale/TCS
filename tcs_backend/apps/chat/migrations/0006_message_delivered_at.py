from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("chat", "0005_roommember_cleared_at"),
    ]

    operations = [
        migrations.AddField(
            model_name="message",
            name="delivered_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
