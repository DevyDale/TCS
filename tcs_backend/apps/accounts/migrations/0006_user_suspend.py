from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0005_user_staff_type'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='is_suspended',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='user',
            name='suspended_reason',
            field=models.CharField(blank=True, default='', max_length=255),
        ),
        migrations.AddField(
            model_name='user',
            name='suspended_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
