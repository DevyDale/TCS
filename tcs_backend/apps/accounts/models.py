import uuid
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.db import models
from django.utils import timezone
from cloudinary.models import CloudinaryField


class UserManager(BaseUserManager):
    def create_user(self, user_id, role, name, date_of_birth=None, password=None, **extra):
        if not user_id:
            raise ValueError("user_id is required")
        user = self.model(user_id=user_id, role=role, name=name,
                          date_of_birth=date_of_birth, **extra)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, user_id, role="admin", name="Admin",
                         date_of_birth="2000-01-01", password=None, **extra):
        extra.setdefault("is_staff",      True)
        extra.setdefault("is_superuser",  True)
        extra.setdefault("is_verified",   True)
        return self.create_user(user_id, role, name, date_of_birth, password, **extra)


class User(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        STUDENT            = "student",            "Student"
        TEACHING_STAFF     = "teaching_staff",     "Teaching Staff"
        NON_TEACHING_STAFF = "non_teaching_staff", "Non-Teaching Staff"
        PARENT             = "parent",             "Parent"
        VISITOR            = "visitor",            "Visitor"
        ADMIN              = "admin",              "Admin"

    id             = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user_id        = models.CharField(max_length=50, unique=True, db_index=True)
    
    role           = models.CharField(max_length=25, choices=Role.choices)
    name           = models.CharField(max_length=150)
    preferred_name = models.CharField(max_length=80, blank=True)
    # Nullable: visitor/parent self-registration collects only username/email/
    # password. Students & staff still always have a DOB (from their records).
    date_of_birth  = models.DateField(null=True, blank=True)
    gender         = models.CharField(max_length=20, blank=True)
    # Mirror of StaffRecord.staff_type for live cross-role checks.
    # "reception" bridges students <-> staff. Resolved/backfilled lazily
    # by apps.accounts.reception.staff_type_of().
    staff_type     = models.CharField(max_length=20, blank=True, default="")
    # Admin-assigned verified fire warden — may trigger evacuation alerts.
    # Never self-claimed.
    is_fire_warden = models.BooleanField(default=False)
    # Admin-designated safeguarding lead — works the child-safety case queue.
    # Tighter than ordinary moderation; never self-claimed.
    is_safeguarding_lead = models.BooleanField(default=False)
    # Student-set: opt out of AI wellbeing support (no scoring of their messages).
    # Honoured by the wellbeing scorer regardless of the school-level flag.
    wellbeing_opt_out = models.BooleanField(default=False)
    # When the student last saw the wellbeing/privacy notice (transparency).
    wellbeing_notice_seen_at = models.DateTimeField(null=True, blank=True)

    email    = models.EmailField(unique=True, null=True, blank=True)
    username = models.CharField(max_length=50, unique=True, null=True, blank=True)

    program         = models.CharField(max_length=100, blank=True)
    subjects_taught = models.TextField(blank=True)
    year_group      = models.CharField(max_length=20, blank=True)

    # ── Cloudinary image fields ───────────────────────────────────
    # folder= keeps assets organised in your Cloudinary media library.
    # blank=True / null=True means no image is fine (default state).
    # django_cleanup will delete the old Cloudinary asset automatically
    # whenever these fields are overwritten or the user is deleted.
    avatar_id = models.IntegerField(null=True, blank=True)
    avatar = CloudinaryField(
        "avatar",
        folder="tcs_studenthub/avatars",
        blank=True,
        null=True,
        # Overwrite existing asset instead of generating a new public_id
        overwrite=True,
        # Store as image resource type (not raw)
        resource_type="image",
    )
    cover = CloudinaryField(
        "cover",
        folder="tcs_studenthub/covers",
        blank=True,
        null=True,
        overwrite=True,
        resource_type="image",
    )

    bio       = models.TextField(max_length=300, blank=True)
    interests = models.JSONField(default=list)
    interests_visibility = models.CharField(            # ← ADD
    max_length=10,
    choices=[('public', 'Public'), ('private', 'Private')],
    default='public',
    )
    location  = models.CharField(max_length=100, blank=True)
    website   = models.URLField(blank=True)
    social_links = models.JSONField(default=dict, blank=True)

    xp        = models.PositiveIntegerField(default=0)
    level     = models.PositiveSmallIntegerField(default=1)
    tokens    = models.PositiveIntegerField(default=100)
    gamer_tag = models.CharField(max_length=30, blank=True)

    # ── Arcade avatar (separate Cloudinary field) ─────────────────
    # Kept separate from the profile avatar so users can have a
    # distinct gaming persona image without touching their profile.
    arcade_avatar = CloudinaryField(
        "arcade_avatar",
        folder="tcs_studenthub/arcade_avatars",
        blank=True,
        null=True,
        overwrite=True,
        resource_type="image",
    )

    is_active   = models.BooleanField(default=True)
    is_staff    = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    # Moderation suspension — kept separate from is_active so account
    # disabling for other reasons stays orthogonal. Enforced at login.
    is_suspended     = models.BooleanField(default=False)
    suspended_reason = models.CharField(max_length=255, blank=True, default="")
    suspended_at     = models.DateTimeField(null=True, blank=True)
    is_available_study  = models.BooleanField(default=False)
    study_subjects      = models.CharField(max_length=200, blank=True, default="")
    is_online   = models.BooleanField(default=False)
    last_seen   = models.DateTimeField(null=True, blank=True)
    date_joined = models.DateTimeField(default=timezone.now)

    followers = models.ManyToManyField("self", symmetrical=False,
                                       related_name="following", blank=True)
    fcm_token             = models.TextField(blank=True)
    notification_settings = models.JSONField(default=dict)
    privacy_settings      = models.JSONField(default=dict)

    USERNAME_FIELD  = "user_id"
    REQUIRED_FIELDS = ["role", "name", "date_of_birth"]
    objects         = UserManager()

    class Meta:
        db_table = "users"
        ordering = ["-date_joined"]

    def __str__(self):
        return f"{self.display_name} [{self.role}]"

    @property
    def display_name(self):
        return self.preferred_name or self.name.split()[0]

    @property
    def is_student(self):
        return self.role == self.Role.STUDENT

    def add_xp(self, amount: int):
        self.xp   += amount
        self.level = max(1, self.xp // 500 + 1)
        self.save(update_fields=["xp", "level"])

    def mark_online(self):
        self.is_online = True
        self.last_seen = timezone.now()
        self.save(update_fields=["is_online", "last_seen"])

    def mark_offline(self):
        self.is_online = False
        self.last_seen = timezone.now()
        self.save(update_fields=["is_online", "last_seen"])