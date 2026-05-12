"""
Group lifecycle signals.

When a group is dissolved (is_active flips True → False), automatically
copy every GroupMaterial into each active member's SavedMaterial library
so nothing they shared in the group is lost.
"""

import logging
from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver

from .models import Group

logger = logging.getLogger(__name__)


# ── Helper: stash pre-save is_active so post_save can detect transitions ──
@receiver(pre_save, sender=Group)
def _stash_old_is_active(sender, instance, **kwargs):
    if not instance.pk:
        instance._was_active_before = True
        return
    try:
        old = Group.objects.only("is_active").get(pk=instance.pk)
        instance._was_active_before = old.is_active
    except Group.DoesNotExist:
        instance._was_active_before = True


# ── Main signal: auto-save materials on dissolution ──────────────────
@receiver(post_save, sender=Group)
def _on_group_dissolved(sender, instance, created, **kwargs):
    if created:
        return
    was_active = getattr(instance, "_was_active_before", True)
    if was_active and not instance.is_active:
        try:
            _auto_save_materials_to_members(instance)
        except Exception:
            logger.exception(
                "Failed to auto-save materials for dissolved group %s",
                instance.pk,
            )


def _auto_save_materials_to_members(group):
    """Copy every GroupMaterial into SavedMaterial for each active member."""
    from apps.chat.models import SavedMaterial

    materials = list(group.materials.all())
    if not materials:
        logger.info("Group %s dissolved — no materials to save", group.pk)
        return

    members_qs = group.memberships.filter(status="active").select_related("user")
    member_users = {m.user for m in members_qs}
    if group.created_by_id:
        member_users.add(group.created_by)

    group_name = (
        getattr(group, "name", None)
        or getattr(group, "title", None)
        or "Dissolved group"
    )

    saved = 0
    for material in materials:
        try:
            file_url = material.file.url if material.file else ""
        except Exception:
            file_url = ""

        title     = material.title or material.file_name or "Untitled"
        file_name = material.file_name or ""
        file_type = material.file_type or ""

        for user in member_users:
            # Idempotent — skip if this exact material was already saved
            if SavedMaterial.objects.filter(
                user=user,
                source_group=group,
                file_url=file_url,
            ).exists():
                continue

            SavedMaterial.objects.create(
                user        = user,
                title       = title,
                file_url    = file_url,
                file_name   = file_name,
                file_type   = file_type,
                subject     = "",
                source_type = "group",
                source_group= group,
                source_name = group_name,
            )
            saved += 1

    logger.info(
        "Group %s dissolved → auto-saved %d material rows across %d members",
        group.pk, saved, len(member_users),
    )


    # ── Activity feed: one entry per former member ─────────────────
    try:
        from apps.activity.models import Activity
        actor = getattr(group, "_dissolved_by", None) or group.created_by
        Activity.objects.bulk_create([
            Activity(
                user        = user,
                actor       = actor,
                verb        = Activity.Verb.GROUP_DISSOLVED,
                target_type = "group",
                target_id   = group.pk,
                target_name = group_name,
                metadata    = {
                    "reason":         group.dissolve_reason or "",
                    "saved_count":    saved,
                    "member_count":   len(member_users),
                },
            )
            for user in member_users
        ])
        logger.info("Activity: emitted dissolve entries for %d members", len(member_users))
    except Exception:
        logger.exception("Activity emit failed for dissolved group %s", group.pk)
