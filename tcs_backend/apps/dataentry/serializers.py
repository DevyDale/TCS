from rest_framework import serializers, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from .models import StudentRecord


# ─────────────────────────────────────────────────────────────
# SERIALIZER
# ─────────────────────────────────────────────────────────────

class StudentSerializer(serializers.ModelSerializer):
    class Meta:
        model            = StudentRecord
        fields           = "__all__"
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate_student_id(self, v):
        if StudentRecord.objects.filter(student_id=v).exists():
            raise serializers.ValidationError("This student ID is already registered.")
        return v

    def validate(self, data):
        # Cross-field check: a student's finishing date must come
        # after their commencement date. Catches typos and stops
        # records that would be deleted by the cleanup job the day
        # they're created.
        com = data.get("date_of_commencement")
        fin = data.get("date_of_finishing")
        if com and fin and fin <= com:
            raise serializers.ValidationError({
                "date_of_finishing": "Must be after the commencement date."
            })
        return data