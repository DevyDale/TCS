import uuid
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('ai', '0002_mentormessage'),
    ]

    operations = [
        migrations.CreateModel(
            name='KnowledgeDoc',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('title', models.CharField(max_length=200)),
                ('subject', models.CharField(blank=True, default='', max_length=80)),
                ('filename', models.CharField(blank=True, default='', max_length=255)),
                ('char_count', models.PositiveIntegerField(default=0)),
                ('chunk_count', models.PositiveIntegerField(default=0)),
                ('is_active', models.BooleanField(db_index=True, default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('uploaded_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='knowledge_docs', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'ai_knowledge_docs', 'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='KnowledgeChunk',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('ordinal', models.PositiveIntegerField(default=0)),
                ('content', models.TextField()),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('doc', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='chunks', to='ai.knowledgedoc')),
            ],
            options={'db_table': 'ai_knowledge_chunks', 'ordering': ['doc', 'ordinal']},
        ),
        migrations.AddIndex(
            model_name='knowledgechunk',
            index=models.Index(fields=['doc', 'ordinal'], name='ai_kchunk_doc_ord_idx'),
        ),
    ]
