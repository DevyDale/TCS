"""Merge two parallel migration leaves in the feedback app.

Web container was crash-looping with CommandError:
'Conflicting migrations detected; multiple leaf nodes in the
migration graph: (0003_more_categories, 0004_merge_20260515_1946)'.

0003_more_categories was created locally (more suggestion-box
categories) while 0004_merge_20260515_1946 already existed on the
server merging some earlier branch. They ended up as parallel
leaves because they were created independently and neither
depends on the other.

This is an empty merge — no operations, just declares both leaves
as dependencies so the graph linearizes.
"""
from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ('feedback', '0003_more_categories'),
        ('feedback', '0004_merge_20260515_1946'),
    ]
    operations = []
