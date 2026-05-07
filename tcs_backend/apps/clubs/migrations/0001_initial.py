# apps/clubs/migrations/0001_initial.py
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import uuid


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="Club",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4,
                                        editable=False, primary_key=True,
                                        serialize=False)),
                ("name",          models.CharField(max_length=120)),
                ("tagline",       models.CharField(blank=True, max_length=200)),
                ("description",   models.TextField(blank=True)),
                ("mission",       models.TextField(blank=True)),
                ("rules",         models.TextField(blank=True)),
                ("purpose",       models.TextField(blank=True)),
                ("contact_email", models.EmailField(blank=True, max_length=254)),
                ("contact_phone", models.CharField(blank=True, max_length=40)),
                ("category", models.CharField(
                    choices=[
                        ("academic",       "Academic"),
                        ("sports",         "Sports"),
                        ("arts",           "Arts"),
                        ("cultural",       "Cultural"),
                        ("technology",     "Technology"),
                        ("social_service", "Social Service"),
                        ("business",       "Business"),
                        ("gaming",         "Gaming"),
                        ("other",          "Other"),
                    ],
                    default="other", max_length=20)),
                ("logo",  models.ImageField(blank=True, null=True,
                                            upload_to="club_logos/%Y/")),
                ("cover", models.ImageField(blank=True, null=True,
                                            upload_to="club_covers/%Y/")),
                ("theme_icon",        models.CharField(blank=True, max_length=10)),
                ("is_public",         models.BooleanField(default=True)),
                ("requires_approval", models.BooleanField(default=False)),
                ("is_verified",       models.BooleanField(default=False)),
                ("is_active",         models.BooleanField(default=True)),
                ("members_count",     models.PositiveIntegerField(default=0)),
                ("created_at",        models.DateTimeField(auto_now_add=True)),
                ("updated_at",        models.DateTimeField(auto_now=True)),
                ("dissolved_at",      models.DateTimeField(blank=True, null=True)),
                ("dissolve_reason",   models.TextField(blank=True)),
                ("created_by", models.ForeignKey(
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name="created_clubs",
                    to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "clubs",
                "ordering": ["-members_count", "-created_at"],
            },
        ),
        migrations.CreateModel(
            name="ClubMember",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True,
                                           serialize=False, verbose_name="ID")),
                ("status", models.CharField(
                    choices=[("active",  "Active"),
                             ("pending", "Pending"),
                             ("banned",  "Banned")],
                    default="active", max_length=10)),
                ("role", models.CharField(
                    choices=[("member",    "Member"),
                             ("executive", "Executive"),
                             ("president", "President")],
                    default="member", max_length=12)),
                ("joined_at", models.DateTimeField(auto_now_add=True)),
                ("club", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="memberships", to="clubs.club")),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "db_table": "club_members",
                "ordering": ["joined_at"],
                "unique_together": {("club", "user")},
            },
        ),
        migrations.AddField(
            model_name="club",
            name="members",
            field=models.ManyToManyField(
                related_name="clubs", through="clubs.ClubMember",
                to=settings.AUTH_USER_MODEL),
        ),
    ]