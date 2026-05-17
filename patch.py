"""
TCS — club-dissolve cascade + 8 suggestion categories.

Run from the project root (the folder that contains tcs_backend/):
    python3 patch.py

End-to-end: patches files, runs migrations, commits and pushes.
Idempotent — every step skips itself if already done. Safe to re-run.
"""
import re
import sys
import pathlib
import subprocess

ROOT = pathlib.Path("tcs_backend")
if not ROOT.is_dir():
    print("ERROR: tcs_backend/ not found. Run this from the TCS project root.")
    sys.exit(1)

results = []
def ok(label):    results.append(("ok",   label, ""))
def skip(label):  results.append(("skip", label, ""))
def fail(label, detail): results.append(("fail", label, detail))


# Helpers ─────────────────────────────────────────────────────

def add_to_fields_list(path, class_name, new_field):
    p = ROOT / path
    if not p.exists():
        fail(f"{path}::{class_name}", "file missing"); return
    s = p.read_text()
    m = re.search(r"class\s+" + re.escape(class_name) + r"\b", s)
    if not m:
        fail(f"{path}::{class_name}", "class not found"); return
    next_class = re.search(r"\nclass\s+\w", s[m.end():])
    end = m.end() + (next_class.start() if next_class else len(s) - m.end())
    block = s[m.start():end]
    fm = re.search(r"fields\s*=\s*\[(.*?)\]", block, re.DOTALL)
    if not fm:
        fail(f"{path}::{class_name}", "fields list not found"); return
    inner = fm.group(1)
    if f'"{new_field}"' in inner or f"'{new_field}'" in inner:
        skip(f"{path}::{class_name}.fields already has {new_field}"); return
    stripped = inner.rstrip()
    if not stripped.endswith(","):
        stripped += ","
    im = re.search(r"\n([ \t]+)\S", inner)
    indent = im.group(1) if im else "            "
    new_inner = stripped + "\n" + indent + f'"{new_field}",'
    new_block = block[:fm.start(1)] + new_inner + block[fm.end(1):]
    p.write_text(s[:m.start()] + new_block + s[end:])
    ok(f"{path}::{class_name}.fields += {new_field}")


# Patches ─────────────────────────────────────────────────────

def patch_post_club():
    p = ROOT / "apps/posts/models.py"
    s = p.read_text()
    if 'related_name="club_posts"' in s:
        skip("apps/posts/models.py (Post.club)"); return
    m = re.search(r"(    tagged_users\s*=\s*models\.ManyToManyField\([^)]*\))",
                  s, re.DOTALL)
    if not m:
        fail("apps/posts/models.py", "tagged_users not found"); return
    addition = (
        "\n\n    # Club association.\n"
        '    club = models.ForeignKey(\n'
        '        "clubs.Club",\n'
        "        null=True, blank=True,\n"
        "        on_delete=models.SET_NULL,\n"
        '        related_name="club_posts",\n'
        "    )"
    )
    p.write_text(s[:m.end()] + addition + s[m.end():])
    ok("apps/posts/models.py (Post.club)")


def patch_event_club():
    p = ROOT / "apps/events/models.py"
    s = p.read_text()
    if 'related_name="club_events"' in s:
        skip("apps/events/models.py (Event.club)"); return
    m = re.search(
        r"(    group\s*=\s*models\.ForeignKey\([^)]*on_delete=models\.SET_NULL\s*\))",
        s, re.DOTALL,
    )
    if not m:
        fail("apps/events/models.py", "group FK not found"); return
    addition = (
        "\n\n    # Club association.\n"
        "    club        = models.ForeignKey(\n"
        '        "clubs.Club", null=True, blank=True,\n'
        "        on_delete=models.SET_NULL,\n"
        '        related_name="club_events",\n'
        "    )"
    )
    p.write_text(s[:m.end()] + addition + s[m.end():])
    ok("apps/events/models.py (Event.club)")


def patch_serializers():
    add_to_fields_list("apps/posts/serializers.py",  "CreatePostSerializer",  "club")
    add_to_fields_list("apps/events/views.py",       "EventSerializer",       "club")
    add_to_fields_list("apps/events/serializers.py", "EventCreateSerializer", "club")


def patch_club_destroy():
    rel = "apps/clubs/views.py"
    p = ROOT / rel
    s = p.read_text()
    if '"posts_removed"' in s:
        skip(rel); return
    cm = re.search(r"class\s+ClubDetailView\b", s)
    if not cm:
        fail(rel, "ClubDetailView not found"); return
    after = s[cm.end():]
    dm = re.search(r"    def destroy\(self,.*?\n    (?=def |\n\nclass |\Z)",
                   after, re.DOTALL)
    if not dm:
        dm = re.search(r"    def destroy\(self,.*?return Response\([^)]+\)\)",
                       after, re.DOTALL)
    if not dm:
        fail(rel, "destroy() method not found"); return
    new_destroy = (
        "    def destroy(self, request, *args, **kwargs):\n"
        "        club = self.get_object()\n"
        "        if not _is_president(club, request.user):\n"
        "            return Response(\n"
        '                {"error": "Only the president can dissolve this club."},\n'
        "                status=403)\n"
        '        reason = (request.data.get("reason", "").strip()\n'
        '                  if request.data else "")\n'
        "\n"
        "        from apps.posts.models  import Post\n"
        "        from apps.events.models import Event\n"
        "\n"
        "        with transaction.atomic():\n"
        "            deleted_posts,  _ = Post.objects.filter(club=club).delete()\n"
        "            deleted_events, _ = Event.objects.filter(club=club).delete()\n"
        "\n"
        "            club.is_active       = False\n"
        "            club.dissolved_at    = timezone.now()\n"
        '            club.dissolve_reason = reason or "Dissolved by president."\n'
        "            club.save(update_fields=[\n"
        '                "is_active", "dissolved_at", "dissolve_reason"])\n'
        "\n"
        "        return Response({\n"
        '            "success":        True,\n'
        '            "message":        "Club dissolved.",\n'
        '            "posts_removed":  deleted_posts,\n'
        '            "events_removed": deleted_events,\n'
        "        })\n"
    )
    a = cm.end() + dm.start()
    b = cm.end() + dm.end()
    p.write_text(s[:a] + new_destroy + s[b:])
    ok(rel + " (destroy cascade)")


def patch_posts_views_filter():
    rel = "apps/posts/views.py"
    p = ROOT / rel
    s = p.read_text()
    if "Q(club__isnull=True)" in s:
        skip(rel); return
    pat = re.compile(r"^([ \t]+)\.exclude\(is_flagged=True\)\)", re.MULTILINE)
    s2, n = pat.subn(
        r"\1.filter(Q(club__isnull=True) | Q(club__is_active=True))\n\1.exclude(is_flagged=True))",
        s,
    )
    if n == 0:
        fail(rel, "no .exclude(is_flagged=True)) lines"); return
    p.write_text(s2)
    ok(f"{rel} ({n} queryset(s))")


def patch_events_views_filter():
    rel = "apps/events/views.py"
    p = ROOT / rel
    s = p.read_text()
    if "Q(club__isnull=True)" in s:
        skip(rel); return
    n_total = 0
    s2, n = re.subn(
        r'        qs\s*=\s*Event\.objects\.filter\(is_active=True\)\.select_related\("organizer"\)',
        '        qs = (Event.objects\n                   .filter(is_active=True)\n'
        '                   .filter(Q(club__isnull=True) | Q(club__is_active=True))\n'
        '                   .select_related("organizer"))',
        s, count=1,
    )
    if n: s = s2; n_total += n
    s2, n = re.subn(
        r"    queryset\s*=\s*Event\.objects\.filter\(is_active=True\)\s*$",
        "    queryset         = (Event.objects\n"
        "                            .filter(is_active=True)\n"
        "                            .filter(Q(club__isnull=True) | Q(club__is_active=True)))",
        s, count=1, flags=re.MULTILINE,
    )
    if n: s = s2; n_total += n
    if n_total == 0:
        fail(rel, "no Event.objects.filter(is_active=True) lines"); return
    p.write_text(s)
    ok(f"{rel} ({n_total} queryset(s))")


def write_migration():
    mig = ROOT / "apps/feedback/migrations/0003_more_categories.py"
    if mig.exists():
        skip(str(mig)); return
    content = (
        "from django.db import migrations\n\n"
        "NEW_CATEGORIES = [\n"
        "    ('praise',   'Praise / Kudos', '\\U0001F31F', '#FFD54F', '#FB8C00',  60),\n"
        "    ('event',    'Event Idea',     '\\U0001F389', '#80DEEA', '#00ACC1',  70),\n"
        "    ('question', 'Question',       '\\u2753',     '#A5D6A7', '#43A047',  80),\n"
        "]\n\n"
        "def add_categories(apps, schema_editor):\n"
        "    Category = apps.get_model('feedback', 'Category')\n"
        "    for key, label, emoji, gfrom, gto, order in NEW_CATEGORIES:\n"
        "        Category.objects.update_or_create(\n"
        "            key=key,\n"
        "            defaults={\n"
        "                'label':         label,\n"
        "                'emoji':         emoji,\n"
        "                'gradient_from': gfrom,\n"
        "                'gradient_to':   gto,\n"
        "                'sort_order':    order,\n"
        "                'is_active':     True,\n"
        "            },\n"
        "        )\n\n"
        "def remove_categories(apps, schema_editor):\n"
        "    Category = apps.get_model('feedback', 'Category')\n"
        "    Category.objects.filter(\n"
        "        key__in=[c[0] for c in NEW_CATEGORIES]\n"
        "    ).delete()\n\n"
        "class Migration(migrations.Migration):\n"
        "    dependencies = [\n"
        "        ('feedback', '0002_categories_overhaul'),\n"
        "    ]\n"
        "    operations = [\n"
        "        migrations.RunPython(add_categories, remove_categories),\n"
        "    ]\n"
    )
    mig.write_text(content)
    ok(str(mig) + " (created)")


# Run ─────────────────────────────────────────────────────────

print("=" * 60)
print("STEP 1: Patching source files")
print("=" * 60)
for fn in (
    patch_post_club,
    patch_event_club,
    patch_serializers,
    patch_club_destroy,
    patch_posts_views_filter,
    patch_events_views_filter,
    write_migration,
):
    try:
        fn()
    except Exception as e:
        fail(fn.__name__, f"exception: {e}")

for status, label, detail in results:
    icon = {"ok": "  [ok]  ", "skip": "  [skip]", "fail": "  [FAIL]"}[status]
    print(icon + " " + label + (("  --  " + detail) if detail else ""))

ok_n   = sum(1 for r in results if r[0] == "ok")
skip_n = sum(1 for r in results if r[0] == "skip")
fail_n = sum(1 for r in results if r[0] == "fail")
print(f"\n{ok_n} applied, {skip_n} skipped, {fail_n} failed\n")


def run(cmd, cwd=None):
    where = f"   (in {cwd})" if cwd else ""
    print(f"$ {' '.join(cmd)}{where}")
    return subprocess.run(cmd, cwd=cwd).returncode


print("=" * 60)
print("STEP 2: Django migrations")
print("=" * 60)
if run(["python", "manage.py", "makemigrations"], cwd="tcs_backend") != 0:
    print("makemigrations failed. Fix and re-run.")
    sys.exit(1)
if run(["python", "manage.py", "migrate"], cwd="tcs_backend") != 0:
    print("migrate failed. Fix and re-run.")
    sys.exit(1)

print()
print("=" * 60)
print("STEP 3: Git commit + push")
print("=" * 60)
run(["git", "add", "-A"])
if subprocess.run(["git", "diff", "--cached", "--quiet"]).returncode == 0:
    print("Nothing to commit.")
else:
    run([
        "git", "commit", "-m",
        "Cascade-delete club content on dissolve; +3 suggestion categories",
    ])
    run(["git", "push"])

print()
print("Done.")
