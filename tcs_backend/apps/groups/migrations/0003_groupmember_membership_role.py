from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("groups", "0002_alter_groupmaterial_file"),
    ]

    operations = [
        migrations.AddField(
            model_name="groupmember",
            name="membership_role",
            field=models.CharField(
                choices=[("member", "Member"), ("mentor", "Mentor")],
                default="member", max_length=8),
        ),
    ]
