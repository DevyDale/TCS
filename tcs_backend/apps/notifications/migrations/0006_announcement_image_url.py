from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("notifications", "0005_announcement"),
    ]

    operations = [
        migrations.AddField(
            model_name="announcement",
            name="image_url",
            field=models.URLField(blank=True, default="", max_length=2000),
        ),
    ]
