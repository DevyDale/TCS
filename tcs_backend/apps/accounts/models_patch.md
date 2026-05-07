# Phase 3 — User model patch
#
# This is NOT a drop-in replacement file (your User model has a lot of
# project-specific fields I don't want to clobber). It's a targeted patch
# you apply to `tcs_backend/apps/accounts/models.py`.
#
# Find this block (in the User model, near the other profile fields):
#
#     bio       = models.TextField(max_length=300, blank=True)
#     interests = models.JSONField(default=list)
#     location  = models.CharField(max_length=100, blank=True)
#     website   = models.URLField(blank=True)
#
# Add a single field RIGHT AFTER `interests`:
#
#     bio       = models.TextField(max_length=300, blank=True)
#     interests = models.JSONField(default=list)
#     interests_visibility = models.CharField(            # ← ADD THIS LINE
#         max_length=10,
#         choices=[('public', 'Public'), ('private', 'Private')],
#         default='public',
#     )
#     location  = models.CharField(max_length=100, blank=True)
#     website   = models.URLField(blank=True)
#
# That's it. Bio visibility is already supported via the existing
# `privacy_settings = models.JSONField(default=dict)` field — the
# serializer reads `privacy_settings.get('bio_public', True)` so no
# new column is needed for it.
