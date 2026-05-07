from django.contrib import admin
from .models import StudentRecord, StaffRecord


@admin.register(StudentRecord)
class StudentRecordAdmin(admin.ModelAdmin):
    list_display  = ["student_id", "full_name", "course_type",
                     "date_of_commencement", "created_at"]
    search_fields = ["student_id", "full_name"]
    list_filter   = ["course_type"]
    readonly_fields = ["created_at", "updated_at"]


@admin.register(StaffRecord)
class StaffRecordAdmin(admin.ModelAdmin):
    list_display  = ["staff_id", "full_name", "staff_type", "created_at"]
    search_fields = ["staff_id", "full_name"]
    list_filter   = ["staff_type"]
    readonly_fields = ["created_at", "updated_at"]
