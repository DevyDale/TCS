from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("ai", "0003_knowledge"),
    ]

    operations = [
        migrations.AddField(
            model_name="knowledgedoc",
            name="retrieval_count",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="knowledgedoc",
            name="last_retrieved_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
