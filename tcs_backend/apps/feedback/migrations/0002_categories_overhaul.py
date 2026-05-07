# apps/feedback/migrations/0002_categories_overhaul.py
#
# Categories overhaul:
#   1. Creates the Category table.
#   2. Seeds the 5 active categories (no 'General' — explicit removal).
#   3. Adds a temporary `category_fk` column on Suggestion.
#   4. Maps each existing Suggestion's old category string to the
#      matching Category row (rows whose old value was 'general' end
#      up NULL; we deliberately don't seed a 'general' category).
#   5. Drops the old `category` CharField and renames `category_fk`
#      to `category`.
#
# Single migration so the field swap is atomic — running `migrate`
# halfway through the sequence cannot leave the DB in an inconsistent
# state.

import uuid

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


def seed_categories(apps, schema_editor):
    Category = apps.get_model('feedback', 'Category')
    seed = [
        # key,        label,             emoji,  from,       to,         sort
        ('feature',   'Feature Request', '💡',   '#6DD5FA', '#8E54E9',   10),
        ('bug',       'Bug Report',      '🐛',   '#FF5858', '#FF9800',   20),
        ('content',   'Content',         '📚',   '#4CAF50', '#2E7D32',   30),
        ('ui',        'Design & UI',     '🎨',   '#CE93D8', '#7B1FA2',   40),
        ('complaint', 'Complaint',       '⚠️',   '#F7971E', '#FF5858',   50),
    ]
    for key, label, emoji, gfrom, gto, order in seed:
        Category.objects.update_or_create(
            key=key,
            defaults={
                'label':         label,
                'emoji':         emoji,
                'gradient_from': gfrom,
                'gradient_to':   gto,
                'sort_order':    order,
                'is_active':     True,
            },
        )


def migrate_existing_categories(apps, schema_editor):
    """Map each existing Suggestion's old `category` string to its
    matching Category row. 'general' rows stay NULL because we don't
    seed a 'general' category (per spec — General is being removed)."""
    Suggestion = apps.get_model('feedback', 'Suggestion')
    Category   = apps.get_model('feedback', 'Category')
    cats = {c.key: c for c in Category.objects.all()}
    for s in Suggestion.objects.all():
        key = (s.category or '').strip().lower()
        cat = cats.get(key)
        if cat is not None:
            s.category_fk = cat
            s.save(update_fields=['category_fk'])


def noop_reverse(apps, schema_editor):
    """No reverse — the old string column is gone after rename."""
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('feedback', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # 1. Create the Category table.
        migrations.CreateModel(
            name='Category',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False,
                                        primary_key=True, serialize=False)),
                ('key', models.SlugField(max_length=40, unique=True)),
                ('label', models.CharField(max_length=80)),
                ('emoji', models.CharField(blank=True, max_length=8)),
                ('gradient_from', models.CharField(default='#6DD5FA', max_length=9)),
                ('gradient_to',   models.CharField(default='#8E54E9', max_length=9)),
                ('sort_order',    models.PositiveSmallIntegerField(default=100)),
                ('is_active',     models.BooleanField(default=True)),
                ('created_at',    models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'db_table': 'feedback_categories',
                'ordering': ['sort_order', 'label'],
            },
        ),

        # 2. Seed the 5 active categories.
        migrations.RunPython(seed_categories, noop_reverse),

        # 3. Add a temporary FK column on Suggestion (separate from the
        #    existing string `category` field).
        migrations.AddField(
            model_name='suggestion',
            name='category_fk',
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='suggestions',
                to='feedback.category',
            ),
        ),

        # 4. Map old string values to the new FK.
        migrations.RunPython(migrate_existing_categories, noop_reverse),

        # 5. Drop the old string column.
        migrations.RemoveField(
            model_name='suggestion',
            name='category',
        ),

        # 6. Rename `category_fk` to `category` so app code and
        #    serializers don't have to care about the old name.
        migrations.RenameField(
            model_name='suggestion',
            old_name='category_fk',
            new_name='category',
        ),
    ]