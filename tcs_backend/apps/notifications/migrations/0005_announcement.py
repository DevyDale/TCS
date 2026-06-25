import uuid
import cloudinary.models
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('notifications', '0004_alter_notification_notif_type'),
    ]

    operations = [
        migrations.CreateModel(
            name='Announcement',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('title', models.CharField(max_length=200)),
                ('body', models.TextField()),
                ('category', models.CharField(choices=[('general', 'General'), ('academic', 'Academic'), ('event', 'Event'), ('job', 'Job / Opportunity'), ('community', 'Community'), ('urgent', 'Urgent')], default='general', max_length=20)),
                ('audience', models.CharField(choices=[('all', 'Everyone'), ('students', 'Students only'), ('staff', 'Staff only'), ('year_group', 'Specific year group')], default='all', max_length=20)),
                ('year_group', models.CharField(blank=True, default='', max_length=20)),
                ('image', cloudinary.models.CloudinaryField(blank=True, max_length=255, null=True, verbose_name='image')),
                ('accent', models.CharField(blank=True, default='', max_length=9)),
                ('is_pinned', models.BooleanField(db_index=True, default=False)),
                ('is_published', models.BooleanField(db_index=True, default=True)),
                ('publish_at', models.DateTimeField(blank=True, null=True)),
                ('expires_at', models.DateTimeField(blank=True, null=True)),
                ('view_count', models.PositiveIntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('author', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='announcements', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'announcements',
                'ordering': ['-is_pinned', '-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='announcement',
            index=models.Index(fields=['audience', 'is_published'], name='announce_aud_pub_idx'),
        ),
        # Add 'announcement' to notif_type choices WITHOUT dropping any of the
        # 18 existing values (mirrors 0004's full list + the new one).
        migrations.AlterField(
            model_name='notification',
            name='notif_type',
            field=models.CharField(
                choices=[
                    ('like', 'Like'),
                    ('comment', 'Comment'),
                    ('follow', 'Follow'),
                    ('mention', 'Mention'),
                    ('chat_message', 'Chat Message'),
                    ('chat_request', 'Chat Request'),
                    ('request_accepted', 'Request Accepted'),
                    ('request_declined', 'Request Declined'),
                    ('group_add', 'Added to Group'),
                    ('group_message', 'Group Message'),
                    ('group_material', 'Group Material'),
                    ('club_event', 'Club Event'),
                    ('game_request', 'Game Request'),
                    ('event_reminder', 'Event Reminder'),
                    ('achievement', 'Achievement'),
                    ('announcement', 'Announcement'),
                    ('system', 'System'),
                    ('birthday', 'Birthday'),
                ],
                max_length=20,
            ),
        ),
    ]
