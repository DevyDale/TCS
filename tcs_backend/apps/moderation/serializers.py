from django.contrib.auth import get_user_model
from django.contrib.contenttypes.models import ContentType
from rest_framework import serializers
from .models import Report, Block, REASON_CHOICES

User = get_user_model()


class ReportCreateSerializer(serializers.ModelSerializer):
    content_type_model = serializers.CharField(
        write_only=True,
        help_text="e.g. 'post', 'comment', 'user'",
    )

    class Meta:
        model  = Report
        fields = ["id", "content_type_model", "object_id", "reason", "description", "created_at"]
        read_only_fields = ["id", "created_at"]

    def validate_content_type_model(self, value):
        try:
            return ContentType.objects.get(model=value.lower())
        except ContentType.DoesNotExist:
            raise serializers.ValidationError(f"Unknown content type: {value}")

    def create(self, validated_data):
        ct = validated_data.pop("content_type_model")
        # If reporting a user, resolve user_id string to User UUID PK.
        if ct.model == "user":
            oid = validated_data.get("object_id", "")
            if oid and "-" not in str(oid):
                u = User.objects.filter(user_id=oid).first()
                if u:
                    validated_data["object_id"] = str(u.id)
        return Report.objects.create(
            reporter=self.context["request"].user,
            content_type=ct,
            **validated_data,
        )


class BlockSerializer(serializers.ModelSerializer):
    blocked      = serializers.SerializerMethodField()
    # Flat fields kept for backwards compatibility with older clients.
    blocked_id   = serializers.CharField(source="blocked.id", read_only=True)
    blocked_name = serializers.CharField(source="blocked.name", read_only=True)

    class Meta:
        model  = Block
        fields = ["id", "blocked", "blocked_id", "blocked_name", "reason", "created_at"]
        read_only_fields = ["id", "created_at"]

    def get_blocked(self, obj):
        u = obj.blocked
        # Prefer the main UserSerializer so the blocked object includes
        # avatar_url, display_name, role etc. Fall back to a minimal
        # hand-built dict if the import or serialization fails.
        try:
            from apps.accounts.serializers import UserSerializer
            return UserSerializer(u, context=self.context).data
        except Exception:
            pass
        avatar = None
        try:
            v = getattr(u, "avatar_url", None)
            if callable(v):
                v = v()
            if v:
                avatar = str(v)
        except Exception:
            pass
        return {
            "id": str(u.id),
            "user_id": getattr(u, "user_id", "") or "",
            "name": getattr(u, "name", "") or "",
            "role": getattr(u, "role", "") or "",
            "preferred_name": getattr(u, "preferred_name", "") or "",
            "avatar_url": avatar,
        }


class BlockCreateSerializer(serializers.Serializer):
    blocked = serializers.CharField()
    reason  = serializers.ChoiceField(choices=REASON_CHOICES, required=False, allow_blank=True)

    def validate_blocked(self, value):
        # Accept either UUID (User.pk) or user_id string like '3005177'.
        user = None
        try:
            user = User.objects.filter(pk=value).first()
        except (ValueError, Exception):
            pass
        if user is None:
            user = User.objects.filter(user_id=value).first()
        if user is None:
            raise serializers.ValidationError("User not found.")
        if user == self.context["request"].user:
            raise serializers.ValidationError("Cannot block yourself.")
        return user
