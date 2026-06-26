from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("events", "0003_alter_event_club"),
    ]

    operations = [
        migrations.AddField(
            model_name="event",
            name="audience",
            field=models.CharField(default="everyone", max_length=8, choices=[
                ("everyone", "Everyone"), ("students", "Students"),
                ("staff", "Staff")]),
        ),
        migrations.AddField(
            model_name="event",
            name="poster_url",
            field=models.URLField(blank=True, default="", max_length=2000),
        ),
    ]
