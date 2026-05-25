"""
setup_totp — enroll a staff/admin user in TOTP-based MFA for the Django admin.

Prints a QR code (right in the terminal) plus a manual secret. Scan it into an
authenticator app (Google Authenticator / Authy / 1Password). Run this BEFORE
setting OTP_ADMIN_ENFORCED=True, so nobody is locked out of /admin/:

    docker compose exec web python manage.py setup_totp <user_id-or-email>

Options:
    --name NAME   Device label (default: "default")
    --reset       Delete any existing TOTP device for the user, then create a
                  fresh one (use if a phone was lost and the old secret is gone)
"""
import base64
import io

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

User = get_user_model()


class Command(BaseCommand):
    help = "Enroll a staff/admin user in TOTP MFA for the Django admin."

    def add_arguments(self, parser):
        parser.add_argument(
            "identifier",
            help="The user's user_id (student/staff ID) or email address",
        )
        parser.add_argument(
            "--name", default="default",
            help="Device label (default: 'default')",
        )
        parser.add_argument(
            "--reset", action="store_true",
            help="Delete any existing TOTP device for this user and create a fresh one",
        )

    def handle(self, *args, **opts):
        # Imported lazily so the project still loads if django-otp / qrcode
        # aren't installed yet (e.g. during a partial deploy).
        from django_otp.plugins.otp_totp.models import TOTPDevice
        import qrcode

        ident = opts["identifier"]
        user = (
            User.objects.filter(user_id=ident).first()
            or User.objects.filter(email__iexact=ident).first()
        )
        if not user:
            raise CommandError(
                f"No user found with user_id or email '{ident}'."
            )

        if not (user.is_staff or user.is_superuser):
            self.stdout.write(self.style.WARNING(
                f"Heads up: {user} is not staff/superuser. MFA only gates the "
                f"Django admin, so this device won't grant any access until the "
                f"account is made staff."
            ))

        if opts["reset"]:
            deleted, _ = TOTPDevice.objects.filter(user=user).delete()
            if deleted:
                self.stdout.write(self.style.WARNING(
                    f"Removed {deleted} existing TOTP device(s) for {user}."
                ))

        device, created = TOTPDevice.objects.get_or_create(
            user=user, name=opts["name"],
            defaults={"confirmed": True},
        )
        if not created and not device.confirmed:
            device.confirmed = True
            device.save(update_fields=["confirmed"])
        if not created:
            self.stdout.write(self.style.WARNING(
                "A device with this name already existed — re-printing it. "
                "Pass --reset to generate a brand-new secret instead."
            ))

        uri = device.config_url
        secret = base64.b32encode(device.bin_key).decode("utf-8")

        self.stdout.write("")
        self.stdout.write(self.style.SUCCESS(
            f"TOTP device ready for {user} (user_id={user.user_id})."
        ))
        self.stdout.write("\nScan this QR code in your authenticator app:\n")

        qr = qrcode.QRCode(border=1)
        qr.add_data(uri)
        qr.make(fit=True)
        buf = io.StringIO()
        qr.print_ascii(out=buf, invert=True)
        self.stdout.write(buf.getvalue())

        self.stdout.write(f"\nOr enter this secret manually: {secret}")
        self.stdout.write(self.style.SUCCESS(
            "\nOnce OTP_ADMIN_ENFORCED=True is set, sign in at /admin/ with your "
            "user_id, password, and the 6-digit code to confirm it works.\n"
        ))
