from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models
from django.utils import timezone


class UserManager(BaseUserManager):
    """Custom user manager for TCS User model."""
    
    def create_user(self, user_id, role, date_of_birth, password=None, **extra_fields):
        """Create and save a regular user."""
        if not user_id:
            raise ValueError("User must have an ID")
        if not role:
            raise ValueError("User must have a role")
        if not date_of_birth:
            raise ValueError("User must have a date of birth")
        
        user = self.model(
            user_id=user_id,
            role=role,
            date_of_birth=date_of_birth,
            **extra_fields
        )
        if password:
            user.set_password(password)
        user.save(using=self._db)
        return user
    
    def create_superuser(self, user_id, role, date_of_birth, password=None, **extra_fields):
        """Create and save a superuser."""
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)
        
        return self.create_user(user_id, role, date_of_birth, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """Custom User model for TCS platform."""
    
    ROLE_CHOICES = [
        ('student', 'Student'),
        ('teaching_staff', 'Teaching Staff'),
        ('non_teaching_staff', 'Non-Teaching Staff'),
        ('parent', 'Parent'),
        ('visitor', 'Visitor'),
    ]
    
    GENDER_CHOICES = [
        ('M', 'Male'),
        ('F', 'Female'),
        ('O', 'Other'),
        ('N', 'Prefer not to say'),
    ]
    
    # Core fields
    user_id = models.CharField(max_length=50, unique=True, db_index=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
    
    # Personal information
    name = models.CharField(max_length=200)
    preferred_name = models.CharField(max_length=100, blank=True, null=True)
    date_of_birth = models.DateField()
    gender = models.CharField(max_length=1, choices=GENDER_CHOICES, blank=True, null=True)
    
    # Contact information (for parents/visitors)
    email = models.EmailField(unique=True, blank=True, null=True)
    username = models.CharField(max_length=150, unique=True, blank=True, null=True)
    
    # Student-specific fields
    program = models.CharField(max_length=200, blank=True, null=True)
    electives = models.TextField(blank=True, null=True)  # Comma-separated or JSON
    
    # Teaching staff-specific fields
    subjects_taught = models.TextField(blank=True, null=True)  # Comma-separated or JSON
    
    # Profile
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)
    bio = models.TextField(blank=True, null=True)
    
    # Account status
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    
    # Timestamps
    date_joined = models.DateTimeField(default=timezone.now)
    last_login = models.DateTimeField(blank=True, null=True)
    
    objects = UserManager()
    
    USERNAME_FIELD = 'user_id'
    REQUIRED_FIELDS = ['role', 'date_of_birth']
    
    class Meta:
        ordering = ['-date_joined']
        verbose_name = 'User'
        verbose_name_plural = 'Users'
    
    def __str__(self):
        return f"{self.name} ({self.user_id}) - {self.get_role_display()}"
    
    def get_display_name(self):
        """Return preferred name if set, otherwise return full name."""
        return self.preferred_name or self.name
