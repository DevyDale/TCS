from rest_framework import serializers
from .models import Activity


class ActivitySerializer(serializers.ModelSerializer):
    actor_name   = serializers.SerializerMethodField()
    actor_avatar = serializers.SerializerMethodField()
    verb_label   = serializers.CharField(source="get_verb_display", read_only=True)

    class Meta:
        model  = Activity
        fields = [
            "id", "verb", "verb_label",
            "target_type", "target_id", "target_name",
            "metadata", "is_read", "created_at",
            "actor_name", "actor_avatar",
        ]

    def get_actor_name(self, obj):
        if not obj.actor:
            return ""
        return (getattr(obj.actor, "first_name", "") or
                getattr(obj.actor, "username", "") or "Someone")

    def get_actor_avatar(self, obj):
        if not obj.actor:
            return ""
        return getattr(obj.actor, "avatar_url", "") or ""
