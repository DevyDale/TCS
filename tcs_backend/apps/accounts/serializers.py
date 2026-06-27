from django.contrib.auth import get_user_model
from rest_framework import serializers
import cloudinary

User = get_user_model()


def _cloudinary_url(field_value, **transform_opts):
    """
    Returns an optimised Cloudinary URL for a CloudinaryField value.
    Falls back to None if the field is empty.

    transform_opts are passed straight to cloudinary.CloudinaryImage.build_url():
      width=800, crop="limit", fetch_format="auto", quality="auto"
    """
    if not field_value:
        return None
    try:
        public_id = str(field_value)
        return cloudinary.CloudinaryImage(public_id).build_url(**transform_opts)
    except Exception:
        return None


class UserMiniSerializer(serializers.ModelSerializer):
    avatar_url    = serializers.SerializerMethodField()
    arcade_avatar_url = serializers.SerializerMethodField()
    staff_type    = serializers.SerializerMethodField()
    is_reception  = serializers.SerializerMethodField()

    class Meta:
        model  = User
        fields = [ "staff_type", "is_reception","id", "user_id", "display_name", "role",
                  "avatar_url", "arcade_avatar_url", "is_online", "level", "xp",
            "is_available_study",
            "study_subjects",
        ]

    def get_avatar_url(self, obj):
        # 200×200 circle crop, WebP, quality auto — perfect for avatars in lists
        return _cloudinary_url(
            obj.avatar,
            width=200, height=200, crop="fill", gravity="face",
            fetch_format="auto", quality="auto", secure=True,
        )

    def get_arcade_avatar_url(self, obj):
        return _cloudinary_url(
            obj.arcade_avatar,
            width=200, height=200, crop="fill", gravity="face",
            fetch_format="auto", quality="auto", secure=True,
        )

    def get_staff_type(self, obj):
        from apps.accounts.reception import staff_type_of
        return staff_type_of(obj) or None

    def get_is_reception(self, obj):
        from apps.accounts.reception import is_reception
        return is_reception(obj)


class UserProfileSerializer(serializers.ModelSerializer):
    avatar_url        = serializers.SerializerMethodField()
    cover_url         = serializers.SerializerMethodField()
    arcade_avatar_url = serializers.SerializerMethodField()
    followers_count   = serializers.SerializerMethodField()
    following_count   = serializers.SerializerMethodField()
    is_following      = serializers.SerializerMethodField()

    class Meta:
        model  = User
        fields = [
            "id", "user_id", "role", "name", "preferred_name", "display_name",
            "gender", "email", "username", "program", "subjects_taught",
            "year_group",
            "avatar_url", "cover_url", "arcade_avatar_url",
            "bio", "interests", "location", "website", "social_links",
            "xp", "level", "tokens", "gamer_tag",
            "is_online", "last_seen", "date_joined", "is_verified",
            "followers_count", "following_count", "is_following",
            "notification_settings", "privacy_settings",
            "is_available_study",
            "study_subjects",
            "is_fire_warden",
            "is_safeguarding_lead",
        ]
        read_only_fields = [
            "id", "user_id", "role", "xp", "level", "tokens", "is_fire_warden",
            "is_safeguarding_lead",
            "is_verified", "date_joined", "is_online", "last_seen",
        ]

    def get_avatar_url(self, obj):
        # Full-size profile avatar: 400 px, face-aware crop
        return _cloudinary_url(
            obj.avatar,
            width=400, height=400, crop="fill", gravity="face",
            fetch_format="auto", quality="auto", secure=True,
        )

    def get_cover_url(self, obj):
        # Cover banner: 1200×400, landscape crop
        return _cloudinary_url(
            obj.cover,
            width=1200, height=400, crop="fill",
            fetch_format="auto", quality="auto", secure=True,
        )

    def get_arcade_avatar_url(self, obj):
        return _cloudinary_url(
            obj.arcade_avatar,
            width=400, height=400, crop="fill", gravity="face",
            fetch_format="auto", quality="auto", secure=True,
        )

    def get_followers_count(self, obj):
        return obj.followers.count()

    def get_following_count(self, obj):
        return obj.following.count()

    def get_is_following(self, obj):
        req = self.context.get("request")
        if req and req.user.is_authenticated:
            return obj.followers.filter(pk=req.user.pk).exists()
        return False


class IDLoginSerializer(serializers.Serializer):
    user_id       = serializers.CharField()
    date_of_birth = serializers.DateField()
    role          = serializers.ChoiceField(
        choices=["student", "teaching_staff", "non_teaching_staff"])

    def validate(self, attrs):
        from apps.dataentry.models import StudentRecord, StaffRecord
        role    = attrs["role"]
        user_id = attrs["user_id"]
        dob     = attrs["date_of_birth"]

        if role == "student":
            try:
                rec = StudentRecord.objects.get(student_id=user_id, date_of_birth=dob)
            except StudentRecord.DoesNotExist:
                raise serializers.ValidationError("Invalid Student ID or date of birth.")
        else:
            try:
                rec = StaffRecord.objects.get(staff_id=user_id, date_of_birth=dob)
            except StaffRecord.DoesNotExist:
                raise serializers.ValidationError("Invalid Staff ID or date of birth.")

        attrs["full_name"]      = rec.full_name
        attrs["preferred_name"] = rec.preferred_name
        return attrs


class PasswordLoginSerializer(serializers.Serializer):
    identifier = serializers.CharField()
    password   = serializers.CharField(write_only=True)


class RegisterSerializer(serializers.ModelSerializer):
    password         = serializers.CharField(write_only=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True)
    # Visitor/parent self-registration collects only username/email/password.
    # Name is derived; DOB is not collected.
    name             = serializers.CharField(required=False, allow_blank=True)
    date_of_birth    = serializers.DateField(required=False, allow_null=True)

    class Meta:
        model  = User
        fields = ["name", "email", "username", "password",
                  "confirm_password", "date_of_birth", "role"]

    def validate_role(self, v):
        if v not in ("parent", "visitor"):
            raise serializers.ValidationError("Only parent/visitor self-registration.")
        return v

    def validate(self, attrs):
        if attrs["password"] != attrs.pop("confirm_password"):
            raise serializers.ValidationError({"confirm_password": "Passwords do not match."})
        # Derive a display name from username (or email) when not supplied.
        if not (attrs.get("name") or "").strip():
            username = (attrs.get("username") or "").strip()
            email = (attrs.get("email") or "").strip()
            attrs["name"] = username or (email.split("@")[0] if email else "Visitor")
        return attrs

    def create(self, validated_data):
        password = validated_data.pop("password")
        user_id  = validated_data["email"]
        return User.objects.create_user(user_id=user_id, password=password, **validated_data)


class UpdateProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model  = User
        fields = [
            "preferred_name", "gender", "bio", "interests",
            "interests_visibility",   # ← REQUIRED (Phase 3)
            "location", "website", "social_links", "gamer_tag",
            "notification_settings", "privacy_settings",
            "is_available_study",
            "study_subjects",
        ]