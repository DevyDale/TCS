# apps/dataentry/management/commands/cleanup_expired_students.py
#
# Run daily (cron / Celery beat). Finds StudentRecords whose
# date_of_finishing has passed and removes the student's entire
# footprint from the system: their User account, all FK-cascaded
# data (posts, comments, chat memberships, follow relationships,
# uploads, scores, etc.), and the StudentRecord itself.
#
# This is destructive and irreversible. Test with --dry-run first.

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.db import transaction

from apps.dataentry.models import StudentRecord

User = get_user_model()


class Command(BaseCommand):
    help = "Delete students whose date_of_finishing has passed."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="List who would be deleted without actually deleting.",
        )

    def handle(self, *args, **options):
        today = timezone.now().date()

        expired = StudentRecord.objects.filter(
            date_of_finishing__isnull=False,
            date_of_finishing__lt=today,
        )

        count = expired.count()
        if count == 0:
            self.stdout.write(self.style.SUCCESS("No expired students found."))
            return

        self.stdout.write(f"Found {count} expired student(s).")

        if options["dry_run"]:
            for rec in expired:
                self.stdout.write(
                    f"  WOULD DELETE: {rec.student_id} "
                    f"({rec.full_name}) — finished {rec.date_of_finishing}"
                )
            self.stdout.write(self.style.WARNING("Dry run — no changes made."))
            return

        deleted_users   = 0
        deleted_records = 0
        with transaction.atomic():
            for rec in expired:
                # The User row, if present, cascades to everything
                # else by virtue of FK on_delete settings already in
                # the codebase (posts.author, chat.RoomMember.user,
                # comments.author, uploads.uploaded_by, etc).
                try:
                    user = User.objects.get(user_id=rec.student_id)
                    user.delete()
                    deleted_users += 1
                except User.DoesNotExist:
                    # Registered but never logged in — only the
                    # dataentry record exists.
                    pass

                rec.delete()
                deleted_records += 1
                self.stdout.write(f"  Deleted {rec.student_id} ({rec.full_name})")

        self.stdout.write(self.style.SUCCESS(
            f"Done. Removed {deleted_users} user account(s) "
            f"and {deleted_records} record(s)."
        ))