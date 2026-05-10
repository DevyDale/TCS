# apps/accounts/role_perms.py
#
# Role-based visibility helpers for the accounts app.
#
# This module exists because views.py imports four symbols from it:
#     is_cross_role, visible_user_qs, STUDENT_ROLES, STAFF_ROLES
#
# Default policy is permissive: any authenticated viewer can see any
# other user. Tighten by editing visible_user_qs() if/when role gating
# is required (e.g. students shouldn't see staff suggestions, etc.).
#
# Role buckets follow User.Role in models.py.

from django.contrib.auth import get_user_model

User = get_user_model()

# ─── Role groups ─────────────────────────────────────────────
# Match the values in User.Role (apps/accounts/models.py).
STUDENT_ROLES = frozenset({"student"})
STAFF_ROLES   = frozenset({"teaching_staff", "non_teaching_staff", "admin"})
OTHER_ROLES   = frozenset({"parent", "visitor"})


def _bucket(role: str) -> str:
    """Reduce a role string to one of: 'student' | 'staff' | 'other'."""
    if role in STUDENT_ROLES:
        return "student"
    if role in STAFF_ROLES:
        return "staff"
    return "other"


def is_cross_role(viewer, target) -> bool:
    """
    True when `viewer` and `target` belong to different role buckets
    (e.g. a student looking at a staff member).

    Returns False when:
      - either side is None / not authenticated
      - both sides are in the same bucket
    """
    if not viewer or not target:
        return False
    if not getattr(viewer, "is_authenticated", False):
        return False
    viewer_role = getattr(viewer, "role", "") or ""
    target_role = getattr(target, "role", "") or ""
    return _bucket(viewer_role) != _bucket(target_role)


def visible_user_qs(viewer, base_qs=None):
    """
    Returns a queryset of users that `viewer` is allowed to see.

    Default policy:
      - Anonymous viewers     → empty queryset (see nobody)
      - Authenticated viewers → see everybody

    To restrict cross-role visibility (e.g. students can only see
    other students + admins), filter `qs` here based on
    _bucket(viewer.role) before returning.
    """
    qs = base_qs if base_qs is not None else User.objects.all()
    if not viewer or not getattr(viewer, "is_authenticated", False):
        return qs.none()
    return qs