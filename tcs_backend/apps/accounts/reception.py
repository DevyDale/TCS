# apps/accounts/reception.py
"""
Reception-aware cross-role visibility helpers.

A user's coarse role lives on User.role (student / teaching_staff /
non_teaching_staff / parent / visitor / admin). The fine staff category
("reception", "teaching", ...) lives on StaffRecord.staff_type, keyed by
StaffRecord.staff_id == User.user_id. Reception staff sign up as
role="non_teaching_staff", so role alone can't identify them — we resolve
it from StaffRecord (and cache onto User.staff_type when present).

THE RULE
  Students and staff are separated EXCEPT:
    - club posts + event posts (community content) -> visible to everyone
    - reception staff -> the bridge: mutually visible/interactable with
      BOTH students and staff.
  The ONLY blocked pairing is  student  x  staff-who-is-not-reception.
"""
from django.db.models import Q

STUDENT     = "student"
STAFF_ROLES = ("teaching_staff", "non_teaching_staff")


def staff_type_of(user):
    """Resolved staff_type ('reception', ...) for a User, or ''."""
    if user is None:
        return ""
    st = (getattr(user, "staff_type", "") or "").strip().lower()
    if st:
        return st
    if (getattr(user, "role", "") or "") in STAFF_ROLES:
        try:
            from apps.dataentry.models import StaffRecord
            rec = StaffRecord.objects.filter(staff_id=user.user_id).first()
            if rec and rec.staff_type:
                st = rec.staff_type.strip().lower()
                if hasattr(user, "staff_type"):
                    try:
                        user.staff_type = st
                        user.save(update_fields=["staff_type"])
                    except Exception:
                        pass
                return st
        except Exception:
            pass
    return ""


def is_reception(user):
    return staff_type_of(user) == "reception"


def role_group(user_or_role):
    role = (user_or_role if isinstance(user_or_role, str)
            else (getattr(user_or_role, "role", "") or "")).lower()
    if role == STUDENT:
        return "student"
    if role in STAFF_ROLES:
        return "staff"
    return "other"


def can_interact(a, b):
    """
    Symmetric. False for:
      • student x non-reception-staff (cross-role separation), OR
      • either user having blocked the other.
    """
    if a is None or b is None:
        return False
    # Blocking severs interaction both ways — a blocked person can never
    # DM or send a chat request to the blocker again, and vice-versa.
    try:
        from apps.moderation.utils import is_blocked_between
        if is_blocked_between(a, b):
            return False
    except Exception:
        pass
    ga, gb = role_group(a), role_group(b)
    if {ga, gb} == {"student", "staff"}:
        staff_user = a if ga == "staff" else b
        return is_reception(staff_user)
    return True


def _reception_user_ids():
    try:
        from apps.dataentry.models import StaffRecord
        return list(StaffRecord.objects
                    .filter(staff_type="reception")
                    .values_list("staff_id", flat=True))
    except Exception:
        return []


def visible_user_qs(viewer, qs=None):
    """Restrict a User queryset to people `viewer` may see."""
    from django.contrib.auth import get_user_model
    User = get_user_model()
    if qs is None:
        qs = User.objects.all()

    g = role_group(viewer)
    if g == "other":
        return qs
    if g == "staff" and is_reception(viewer):
        return qs                      # reception bridges both sides

    recep_ids = _reception_user_ids()
    if g == "student":                 # students: non-staff + reception staff
        return qs.filter(
            ~Q(role__in=STAFF_ROLES)
            | Q(staff_type="reception")
            | Q(user_id__in=recep_ids)
        )
    return qs.exclude(role=STUDENT)     # non-reception staff: no students


def feed_post_q(viewer, author_field="author", club_field="club"):
    """
    Q() for posts a viewer may see in a personal feed / post-search:
      - any post attached to a club (community)             -> always, OR
      - any post whose author is visible to the viewer.
    Event posts arrive via their own endpoint and are unaffected.
    NOTE: assumes Post has a nullable FK named `club`. Change club_field
    at the call site if yours differs.
    """
    visible_ids = visible_user_qs(viewer).values_list("id", flat=True)
    return (Q(**{f"{club_field}__isnull": False})
            | Q(**{f"{author_field}__in": visible_ids}))
