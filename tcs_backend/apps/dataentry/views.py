from rest_framework import serializers, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from .models import StudentRecord, StaffRecord


class StudentSerializer(serializers.ModelSerializer):
    class Meta:
        model  = StudentRecord
        fields = "__all__"
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate_student_id(self, v):
        if StudentRecord.objects.filter(student_id=v).exists():
            raise serializers.ValidationError("This student ID is already registered.")
        return v


class StaffSerializer(serializers.ModelSerializer):
    class Meta:
        model  = StaffRecord
        fields = "__all__"
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate_staff_id(self, v):
        if StaffRecord.objects.filter(staff_id=v).exists():
            raise serializers.ValidationError("This staff ID is already registered.")
        return v


@api_view(["POST"])
@permission_classes([AllowAny])
def register_student(request):
    ser = StudentSerializer(data=request.data)
    if not ser.is_valid():
        if "student_id" in ser.errors:
            return Response({"detail": ser.errors["student_id"][0]},
                            status=status.HTTP_409_CONFLICT)
        return Response(ser.errors, status=400)
    ser.save()
    return Response({"success": True, "message": "Student registered."},
                    status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([AllowAny])
def register_staff(request):
    ser = StaffSerializer(data=request.data)
    if not ser.is_valid():
        if "staff_id" in ser.errors:
            return Response({"detail": ser.errors["staff_id"][0]},
                            status=status.HTTP_409_CONFLICT)
        return Response(ser.errors, status=400)
    ser.save()
    return Response({"success": True, "message": "Staff registered."},
                    status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([AllowAny])
def get_student(request, student_id):
    try:
        rec = StudentRecord.objects.get(student_id=student_id)
        return Response(StudentSerializer(rec).data)
    except StudentRecord.DoesNotExist:
        return Response({"detail": "Not found."}, status=404)


@api_view(["GET"])
@permission_classes([AllowAny])
def get_staff(request, staff_id):
    try:
        rec = StaffRecord.objects.get(staff_id=staff_id)
        return Response(StaffSerializer(rec).data)
    except StaffRecord.DoesNotExist:
        return Response({"detail": "Not found."}, status=404)
