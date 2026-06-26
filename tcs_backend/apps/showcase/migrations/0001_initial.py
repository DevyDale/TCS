import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("posts", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="ShowcaseReaction",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ("reaction", models.CharField(max_length=7, choices=[
                    ("like", "Like"), ("dislike", "Dislike")])),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("post", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="showcase_reactions", to="posts.post")),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="showcase_reactions", to=settings.AUTH_USER_MODEL)),
            ],
            options={"db_table": "showcase_reaction",
                     "unique_together": {("user", "post")}},
        ),
    ]
