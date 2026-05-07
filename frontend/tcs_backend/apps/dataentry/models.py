from django.db import models


class StudentRecord(models.Model):
    class CourseType(models.TextChoices):
        STANDARD  = "standard",  "Standard Programme"
        INTENSIVE = "intensive", "Intensive Programme"

    full_name            = models.CharField(max_length=150)
    preferred_name       = models.CharField(max_length=80, blank=True)
    student_id           = models.CharField(max_length=50, unique=True, db_index=True)
    date_of_birth        = models.DateField()
    course_type          = models.CharField(max_length=20, choices=CourseType.choices)
    date_of_commencement = models.DateField()
    created_at           = models.DateTimeField(auto_now_add=True)
    updated_at           = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "student_records"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.full_name} ({self.student_id})"


class StaffRecord(models.Model):
    class StaffType(models.TextChoices):
        TEACHING       = "teaching",       "Teaching"
        SECURITY       = "security",       "Security"
        CLEANING       = "cleaning",       "Cleaning"
        ADMINISTRATIVE = "administrative", "Administrative"
        RECEPTION      = "reception",      "Reception"

    staff_type     = models.CharField(max_length=20, choices=StaffType.choices)
    staff_id       = models.CharField(max_length=50, unique=True, db_index=True)
    full_name      = models.CharField(max_length=150)
    preferred_name = models.CharField(max_length=80, blank=True)
    date_of_birth  = models.DateField()
    created_at     = models.DateTimeField(auto_now_add=True)
    updated_at     = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "staff_records"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.full_name} ({self.staff_id})"
