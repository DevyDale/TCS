from django.db import models
from django.utils import timezone


class Submission(models.Model):
    """Model for self-service data entry submissions."""
    
    STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    
    ROLE_CHOICES = [
        ('student', 'Student'),
        ('teaching_staff', 'Teaching Staff'),
        ('non_teaching_staff', 'Non-Teaching Staff'),
    ]
    
    # Submission details
    user_id = models.CharField(max_length=50, db_index=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
    name = models.CharField(max_length=200)
    preferred_name = models.CharField(max_length=100, blank=True, null=True)
    date_of_birth = models.DateField()
    gender = models.CharField(max_length=1, blank=True, null=True)
    
    # Student-specific
    program = models.CharField(max_length=200, blank=True, null=True)
    electives = models.TextField(blank=True, null=True)
    
    # Teaching staff-specific
    subjects_taught = models.TextField(blank=True, null=True)
    
    # Verification
    token = models.CharField(max_length=100, blank=True, null=True, unique=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    
    # Timestamps
    submitted_at = models.DateTimeField(default=timezone.now)
    reviewed_at = models.DateTimeField(blank=True, null=True)
    reviewed_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='reviewed_submissions'
    )
    
    # Additional info
    notes = models.TextField(blank=True, null=True)
    
    class Meta:
        ordering = ['-submitted_at']
        verbose_name = 'Submission'
        verbose_name_plural = 'Submissions'
    
    def __str__(self):
        return f"{self.name} ({self.user_id}) - {self.status}"
