# apps/highlights/migrations/0003_highlightitemlike_highlightitemcomment.py
import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("highlights", "0002_highlightitem_caption"),
    ]

    operations = [
        migrations.CreateModel(
            name="HighlightItemLike",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True,
                                           serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("item", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="likes", to="highlights.highlightitem")),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "highlight_item_likes",
            },
        ),
        migrations.CreateModel(
            name="HighlightItemComment",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("text", models.TextField(max_length=1000)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("author", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    to=settings.AUTH_USER_MODEL)),
                ("item", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="comments", to="highlights.highlightitem")),
            ],
            options={
                "db_table": "highlight_item_comments",
                "ordering": ["created_at"],
            },
        ),
        migrations.AlterUniqueTogether(
            name="highlightitemlike",
            unique_together={("item", "user")},
        ),
    ]
