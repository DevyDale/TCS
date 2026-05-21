from rest_framework import serializers
from .models import BlockedUser, Report


class BlockedUserSerializer(serializers.ModelSerializer):
    user_id      = serializers.CharField(source="blocked.user_id",      read_only=True)
    display_name = serializers.CharField(source="blocked.display_name", read_only=True)
    role         = serializers.CharField(source="blocked.role",         read_only=True)

    class Meta:
        model  = BlockedUser
        fields = ["user_id", "display_name", "role", "created_at"]


class ReportSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Report
        fields = ["id", "target_type", "target_id", "reason", "detail",
                  "status", "created_at"]
        read_only_fields = ["id", "status", "created_at"]
