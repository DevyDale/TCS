import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("feedback", "0006_school_category"),
    ]

    operations = [
        migrations.AddField(
            model_name="suggestion",
            name="priority",
            field=models.IntegerField(default=0),
        ),
        migrations.AddField(
            model_name="suggestion",
            name="assigned_to",
            field=models.ForeignKey(blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="assigned_suggestions", to=settings.AUTH_USER_MODEL),
        ),
        migrations.AddField(
            model_name="suggestion",
            name="theme",
            field=models.CharField(blank=True, default="", max_length=80),
        ),
        migrations.AddField(
            model_name="suggestion",
            name="is_flagged",
            field=models.BooleanField(default=False),
        ),
    ]
