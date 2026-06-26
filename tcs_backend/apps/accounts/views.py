from apps.accounts.role_filter import filter_users_by_role, can_follow
from django.contrib.auth import get_user_model
from django.db.models import Q, Count
from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, permission_classes, authentication_classes
from rest_framework.throttling import ScopedRateThrottle
from django.core.cache import cache
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from .role_perms import is_cross_role, visible_user_qs, STUDENT_ROLES, STAFF_ROLES

from .serializers import (
    IDLoginSerializer, PasswordLoginSerializer, RegisterSerializer,
    UserProfileSerializer, UserMiniSerializer, UpdateProfileSerializer,
    _cloudinary_url,
)

# ✅ NEW IMPORT (Phase 3)
from .serializers_other import OtherUserProfileSerializer

User = get_user_model()


def _tokens(user):
    refresh = RefreshToken.for_user(user)
    # Embed the role in both tokens so the showcase-lockdown middleware can gate
    # low-trust (visitor/parent) accounts cheaply without a DB hit per request.
    refresh["role"] = user.role
    access = refresh.access_token
    access["role"] = user.role
    return {
        "success": True,
        "access":  str(access),
        "refresh": str(refresh),
        "user":    UserProfileSerializer(user).data,
    }


class IDLoginView(generics.GenericAPIView):
    serializer_class       = IDLoginSerializer
    permission_classes     = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes       = [ScopedRateThrottle]
    throttle_scope         = "login"

    def post(self, request):
        ser = self.get_serializer(data=request.data)
        ser.is_valid(raise_exception=True)
        d = ser.validated_data

        user, created = User.objects.get_or_create(
            user_id=d["user_id"],
            defaults={
                "role":           d["role"],
                "name":           d["full_name"],
                "preferred_name": d["preferred_name"],
                "date_of_birth":  d["date_of_birth"],
                "is_verified":    True,
            },
        )
        if not created and not user.is_verified:
            user.is_verified = True
            user.save(update_fields=["is_verified"])

        # Moderation: suspended accounts cannot obtain new tokens.
        if user.is_suspended:
            return Response(
                {"detail": "Your account has been suspended.",
                 "reason": user.suspended_reason or ""},
                status=status.HTTP_403_FORBIDDEN,
            )

        user.mark_online()
        return Response(_tokens(user))


class PasswordLoginView(generics.GenericAPIView):
    serializer_class       = PasswordLoginSerializer
    permission_classes     = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes       = [ScopedRateThrottle]
    throttle_scope         = "login"

    # Native per-account lockout. This fits our manual check_password flow
    # (django-axes hooks into authenticate(), which we don't call) and is
    # NAT-safe — it keys on the account, so one attacker can't lock out a
    # whole campus sharing a public IP, and locking one account doesn't
    # affect anyone else. All cache calls fail OPEN: a cache hiccup must
    # never block a legitimate login.
    LOCKOUT_THRESHOLD = 8          # failed attempts before lock
    LOCKOUT_SECONDS   = 15 * 60    # lock window

    @staticmethod
    def _fail_key(identifier):
        return f"login_fail:{(identifier or '').strip().lower()}"

    def post(self, request):
        ser = self.get_serializer(data=request.data)
        ser.is_valid(raise_exception=True)
        identifier = ser.validated_data["identifier"]
        password   = ser.validated_data["password"]

        key = self._fail_key(identifier)

        # Locked out? (fail open if cache is unavailable)
        try:
            if (cache.get(key) or 0) >= self.LOCKOUT_THRESHOLD:
                return Response(
                    {"success": False,
                     "error": "Too many failed attempts. Try again in about 15 minutes."},
                    status=status.HTTP_429_TOO_MANY_REQUESTS)
        except Exception:
            pass

        user = User.objects.filter(
            Q(email=identifier) | Q(username=identifier)
        ).first()

        if not user or not user.check_password(password):
            # Count this failure (fail open)
            try:
                cache.set(key, (cache.get(key) or 0) + 1, self.LOCKOUT_SECONDS)
            except Exception:
                pass
            return Response({"success": False, "error": "Invalid credentials."},
                            status=status.HTTP_401_UNAUTHORIZED)
        if not user.is_active:
            return Response({"success": False, "error": "Account suspended."},
                            status=status.HTTP_403_FORBIDDEN)

        # Successful login clears the failure counter (fail open)
        try:
            cache.delete(key)
        except Exception:
            pass

        user.mark_online()
        return Response(_tokens(user))


class RegisterView(generics.CreateAPIView):
    serializer_class       = RegisterSerializer
    permission_classes     = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes       = [ScopedRateThrottle]
    throttle_scope         = "register"

    def create(self, request, *args, **kwargs):
        ser = self.get_serializer(data=request.data)
        ser.is_valid(raise_exception=True)
        user = ser.save()
        return Response({"success": True, "user_id": str(user.id)},
                        status=status.HTTP_201_CREATED)


class LogoutView(generics.GenericAPIView):
    def post(self, request):
        try:
            RefreshToken(request.data.get("refresh", "")).blacklist()
        except Exception:
            pass

        request.user.mark_offline()
        return Response({"success": True})


class MeView(generics.RetrieveUpdateAPIView):
    def get_object(self):
        return self.request.user

    def get_serializer_class(self):
        if self.request.method in ("PUT", "PATCH"):
            return UpdateProfileSerializer
        return UserProfileSerializer


# ✅ FIXED: Privacy-aware user detail view
class UserDetailView(generics.RetrieveAPIView):
    """
    GET /api/users/<user_id>/

    If user is viewing themselves → full profile
    If viewing someone else → apply privacy rules
    """
    queryset     = User.objects.all()
    lookup_field = "user_id"

    def get_serializer_class(self):
        target_id = self.kwargs.get("user_id")

        if (
            self.request.user.is_authenticated
            and self.request.user.user_id == target_id
        ):
            return UserProfileSerializer

        return OtherUserProfileSerializer

    def get_serializer_context(self):
        return {"request": self.request}


# ── Suggested users ───────────────────────────────────────────────
class SuggestedUsersView(generics.ListAPIView):
    serializer_class = UserMiniSerializer

    def get_queryset(self):
        me            = self.request.user
        following_ids = me.following.values_list("id", flat=True)
        limit         = int(self.request.query_params.get("limit", 20))

        qs = (
            User.objects
            .exclude(id=me.id)
            .exclude(id__in=following_ids)
        )
        qs = visible_user_qs(me, qs)  # ← NEW LINE
        qs = qs.annotate(follower_count=Count("followers")).order_by("-follower_count")[:limit]
        return qs
# ── Media uploads ────────────────────────────────────────────────

@api_view(["POST"])
def upload_avatar(request):
    file = request.FILES.get("avatar")
    if not file:
        return Response({"error": "No file provided."}, status=400)

    request.user.avatar = file
    request.user.save(update_fields=["avatar"])

    url = _cloudinary_url(
        request.user.avatar,
        width=400, height=400, crop="fill", gravity="face",
        fetch_format="auto", quality="auto", secure=True,
    )
    return Response({"avatar_url": url})


@api_view(["POST"])
def upload_cover(request):
    file = request.FILES.get("cover")
    if not file:
        return Response({"error": "No file provided."}, status=400)

    request.user.cover = file
    request.user.save(update_fields=["cover"])

    url = _cloudinary_url(
        request.user.cover,
        width=1200, height=400, crop="fill",
        fetch_format="auto", quality="auto", secure=True,
    )
    return Response({"cover_url": url})


@api_view(["POST"])
def upload_arcade_avatar(request):
    file = request.FILES.get("avatar")
    if not file:
        return Response({"error": "No file provided."}, status=400)

    request.user.arcade_avatar = file
    request.user.save(update_fields=["arcade_avatar"])

    url = _cloudinary_url(
        request.user.arcade_avatar,
        width=400, height=400, crop="fill", gravity="face",
        fetch_format="auto", quality="auto", secure=True,
    )
    return Response({"arcade_avatar_url": url})


# ── Follow ────────────────────────────────────────────────────────
@api_view(["POST"])
def follow_toggle(request, user_id):
    try:
        target = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        return Response({"error": "User not found."}, status=404)

    if target == request.user:
        return Response({"error": "Cannot follow yourself."}, status=400)

    # Cross-role block: students and staff cannot follow each other.
    if is_cross_role(request.user, target):
        return Response(
            {"error": "Students and staff can't follow each other."},
            status=403,
        )

    if target.followers.filter(pk=request.user.pk).exists():
        target.followers.remove(request.user)
        action = "unfollowed"
    else:
        target.followers.add(request.user)
        action = "followed"

    return Response({
        "action": action,
        "followers_count": target.followers.count()
    })
# ── Search ────────────────────────────────────────────────────────
@api_view(["GET"])
def search_users(request):
    q = request.query_params.get("q", "").strip()

    if len(q) < 2:
        return Response({"results": []})

    base = User.objects.filter(
        Q(name__icontains=q) |
        Q(preferred_name__icontains=q) |
        Q(username__icontains=q) |
        Q(user_id__icontains=q)
    ).exclude(pk=request.user.pk)

    # Hide the opposite role group from students/staff.
    base = visible_user_qs(request.user, base)

    return Response({
        "results": UserMiniSerializer(
            base[:20], many=True, context={"request": request}
        ).data
    })
@api_view(["POST"])
def update_fcm_token(request):
    token = request.data.get("fcm_token", "")
    request.user.fcm_token = token
    request.user.save(update_fields=["fcm_token"])
    return Response({"success": True})


# ── Verification ────────────────────────────────────────────────

@api_view(["POST"])
@authentication_classes([])
@permission_classes([permissions.AllowAny])
def verify_student(request):
    from apps.dataentry.models import StudentRecord

    sid = request.data.get("student_id", "")
    dob = request.data.get("date_of_birth", "")

    try:
        rec = StudentRecord.objects.get(student_id=sid, date_of_birth=dob)
        return Response({
            "success": True,
            "full_name": rec.full_name,
            "preferred_name": rec.preferred_name
        })
    except StudentRecord.DoesNotExist:
        return Response({"success": False}, status=401)


@api_view(["POST"])
@authentication_classes([])
@permission_classes([permissions.AllowAny])
def verify_staff(request):
    from apps.dataentry.models import StaffRecord

    sid = request.data.get("staff_id", "")
    dob = request.data.get("date_of_birth", "")

    try:
        rec = StaffRecord.objects.get(staff_id=sid, date_of_birth=dob)
        return Response({
            "success": True,
            "full_name": rec.full_name,
            "preferred_name": rec.preferred_name
        })
    except StaffRecord.DoesNotExist:
        return Response({"success": False}, status=401)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def delete_account(request):
    """
    POST /api/accounts/delete/

    Permanently deletes the requesting user's own account and everything that
    cascades from it (profile, posts, messages, memberships, arcade progress).
    Irreversible — the client must confirm with the user before calling this.
    No PROTECT foreign keys reference User, so the cascade completes cleanly.

    Note: ID-login accounts can sign in again with the same student/staff ID,
    which creates a fresh, empty account — deletion removes the data, it does
    not permanently bar the ID.
    """
    user = request.user

    # Best-effort: blacklist outstanding refresh tokens so any other sessions
    # die immediately. The row delete below also cascades these, and the
    # access token stops authenticating the moment the user row is gone.
    try:
        from rest_framework_simplejwt.token_blacklist.models import (
            OutstandingToken, BlacklistedToken,
        )
        for tok in OutstandingToken.objects.filter(user=user):
            BlacklistedToken.objects.get_or_create(token=tok)
    except Exception:
        pass

    user.delete()
    return Response({"success": True}, status=status.HTTP_200_OK)
