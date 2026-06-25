from django.db import migrations


def add_school_category(apps, schema_editor):
    Category = apps.get_model("feedback", "Category")
    Category.objects.update_or_create(
        key="school",
        defaults={
            "label": "To the School",
            "emoji": "\U0001F3EB",  # 🏫
            "gradient_from": "#4F46E5",
            "gradient_to": "#8E54E9",
            "sort_order": 1,         # surface it near the top
            "is_active": True,
        },
    )


def remove_school_category(apps, schema_editor):
    Category = apps.get_model("feedback", "Category")
    Category.objects.filter(key="school").delete()


class Migration(migrations.Migration):

    dependencies = [
        ("feedback", "0005_merge_leaves"),
    ]

    operations = [
        migrations.RunPython(add_school_category, remove_school_category),
    ]
