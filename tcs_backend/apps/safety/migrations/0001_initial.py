# Initial migration for the safety app (block + report). Django 4.2-compatible.

import django.db.models.deletion
import uuid
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='BlockedUser',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('reason', models.CharField(blank=True, max_length=300)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('blocked', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='blocks_received', to=settings.AUTH_USER_MODEL)),
                ('blocker', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='blocks_made', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'blocked_users',
                'ordering': ['-created_at'],
                'indexes': [models.Index(fields=['blocker'], name='blocked_blocker_idx'), models.Index(fields=['blocked'], name='blocked_blocked_idx')],
                'unique_together': {('blocker', 'blocked')},
            },
        ),
        migrations.CreateModel(
            name='Report',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('target_type', models.CharField(choices=[('user', 'User'), ('post', 'Post'), ('comment', 'Comment')], max_length=10)),
                ('target_id', models.CharField(max_length=64)),
                ('reason', models.CharField(choices=[('spam', 'Spam or scam'), ('harassment', 'Harassment or bullying'), ('hate', 'Hate speech'), ('violence', 'Violence or threats'), ('sexual', 'Sexual or explicit content'), ('self_harm', 'Self-harm'), ('other', 'Other'), ('auto_filter', 'Auto-flagged by content filter')], default='other', max_length=20)),
                ('detail', models.TextField(blank=True)),
                ('status', models.CharField(choices=[('pending', 'Pending review'), ('actioned', 'Actioned'), ('dismissed', 'Dismissed')], default='pending', max_length=10)),
                ('handled_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('handled_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='reports_handled', to=settings.AUTH_USER_MODEL)),
                ('offender', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='reports_against', to=settings.AUTH_USER_MODEL)),
                ('reporter', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='reports_made', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'moderation_reports',
                'ordering': ['-created_at'],
                'indexes': [models.Index(fields=['status', 'created_at'], name='report_status_idx'), models.Index(fields=['target_type', 'target_id'], name='report_target_idx')],
            },
        ),
    ]
