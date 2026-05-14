# apps/feedback/migrations/0003_add_praise_category.py
#
# Adds a 6th feedback category: "Praise & Thanks" — a positive
# channel so the picker isn't all problem/request-oriented.
# Idempotent via update_or_create, so re-running is safe.

from django.db import migrations


def add_praise_category(apps, schema_editor):
    Category = apps.get_model('feedback', 'Category')
    Category.objects.update_or_create(
        key='praise',
        defaults={
            'label':         'Praise & Thanks',
            'emoji':         '🎉',
            'gradient_from': '#F093FB',
            'gradient_to':   '#F5576C',
            'sort_order':    60,
            'is_active':     True,
        },
    )


def remove_praise_category(apps, schema_editor):
    Category = apps.get_model('feedback', 'Category')
    Category.objects.filter(key='praise').delete()


class Migration(migrations.Migration):

    dependencies = [
        ('feedback', '0002_categories_overhaul'),
    ]

    operations = [
        migrations.RunPython(add_praise_category, remove_praise_category),
    ]
