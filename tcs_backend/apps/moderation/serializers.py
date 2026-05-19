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
        return Report.objects.create(
            reporter=self.context["request"].user,
            content_type=ct,
            **validated_data,
        )


class BlockSerializer(serializers.ModelSerializer):
    blocked_id   = serializers.CharField(source="blocked.id", read_only=True)
    blocked_name = serializers.CharField(source="blocked.name", read_only=True)

    class Meta:
        model  = Block
        fields = ["id", "blocked_id", "blocked_name", "reason", "created_at"]
        read_only_fields = ["id", "created_at"]


class BlockCreateSerializer(serializers.Serializer):
    blocked = serializers.CharField()
    reason  = serializers.ChoiceField(choices=REASON_CHOICES, required=False, allow_blank=True)

    def validate_blocked(self, value):
        try:
            user = User.objects.get(pk=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("User not found.")
        if user == self.context["request"].user:
            raise serializers.ValidationError("Cannot block yourself.")
        return user
