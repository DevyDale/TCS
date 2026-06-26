# apps/showcase/models.py
#
# The ONLY data a visitor/parent (lowest-trust) account can touch. A reaction
# on a public, club-authored showcase post — no social graph, no student PII.

import uuid

from django.conf import settings
from django.db import models


class ShowcaseReaction(models.Model):
    class Kind(models.TextChoices):
        LIKE    = "like",    "Like"
        DISLIKE = "dislike", "Dislike"

    id        = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                  related_name="showcase_reactions")
    post      = models.ForeignKey("posts.Post", on_delete=models.CASCADE,
                                  related_name="showcase_reactions")
    reaction  = models.CharField(max_length=7, choices=Kind.choices)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "showcase_reaction"
        unique_together = [("user", "post")]
