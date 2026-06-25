from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("posts", "0007_alter_post_club"),
    ]

    operations = [
        migrations.AddField(
            model_name="post",
            name="is_ai",
            field=models.BooleanField(default=False, db_index=True),
        ),
    ]
