# apps/accounts/permissions.py
#
# DRF permission classes for role-gated endpoints. These were introduced for
# the announcements module but are generic — reuse anywhere staff-only or
# elevated-staff-only access is needed.
#
# Role buckets mirror apps/accounts/role_perms.py (STAFF_ROLES) and the
# values in User.Role (apps/accounts/models.py).

from rest_framework.permissions import BasePermission

from .role_perms import STAFF_ROLES

# Elevated staff = the roles allowed to perform privileged actions such as
# pinning. Non-teaching staff are intentionally excluded here.
ELEVATED_STAFF_ROLES = frozenset({"teaching_staff", "admin"})


def _role(user) -> str:
    return (getattr(user, "role", "") or "").lower()


class IsStaff(BasePermission):
    """Authenticated user whose role is in STAFF_ROLES (or a superuser)."""

    message = "Staff access required."

    def has_permission(self, request, view):
        u = request.user
        if not (u and getattr(u, "is_authenticated", False)):
            return False
        return bool(getattr(u, "is_superuser", False)) or _role(u) in STAFF_ROLES


class IsElevatedStaff(BasePermission):
    """Teaching staff / admin / superuser only — for privileged actions."""

    message = "Elevated staff access required."

    def has_permission(self, request, view):
        u = request.user
        if not (u and getattr(u, "is_authenticated", False)):
            return False
        return bool(getattr(u, "is_superuser", False)) or _role(u) in ELEVATED_STAFF_ROLES
