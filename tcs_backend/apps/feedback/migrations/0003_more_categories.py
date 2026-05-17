from django.db import migrations

NEW_CATEGORIES = [
    ('praise',   'Praise / Kudos', '\U0001F31F', '#FFD54F', '#FB8C00',  60),
    ('event',    'Event Idea',     '\U0001F389', '#80DEEA', '#00ACC1',  70),
    ('question', 'Question',       '\u2753',     '#A5D6A7', '#43A047',  80),
]

def add_categories(apps, schema_editor):
    Category = apps.get_model('feedback', 'Category')
    for key, label, emoji, gfrom, gto, order in NEW_CATEGORIES:
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

def remove_categories(apps, schema_editor):
    Category = apps.get_model('feedback', 'Category')
    Category.objects.filter(
        key__in=[c[0] for c in NEW_CATEGORIES]
    ).delete()

class Migration(migrations.Migration):
    dependencies = [
        ('feedback', '0002_categories_overhaul'),
    ]
    operations = [
        migrations.RunPython(add_categories, remove_categories),
    ]
