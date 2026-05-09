# Generated for the chat app — adds subject/source fields to SavedMaterial
#
# IMPORTANT: change the dependency below to your latest chat migration
# (run `ls tcs_backend/apps/chat/migrations/` and pick the highest number).
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        # Update this to your latest chat migration before running:
        ("chat",   "0001_initial"),
        ("groups", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="savedmaterial",
            name="subject",
            field=models.CharField(blank=True, max_length=100,
                                   help_text=(
                                       "Subject this material is about — used "
                                       "to group the library and seed quizzes.")),
        ),
        migrations.AddField(
            model_name="savedmaterial",
            name="source_type",
            field=models.CharField(
                blank=True, max_length=20,
                choices=[("chat", "Chat"),
                         ("group", "Study Group"),
                         ("manual", "Manual upload")],
                default="chat",
                help_text="Where this material was saved from."),
        ),
        migrations.AddField(
            model_name="savedmaterial",
            name="source_group",
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="saved_materials",
                to="groups.group",
                help_text=(
                    "If saved from inside a study group "
                    "(or a study-buddy chat tied to a group).")),
        ),
        migrations.AddField(
            model_name="savedmaterial",
            name="source_name",
            field=models.CharField(
                blank=True, max_length=200,
                help_text=(
                    "Display name of the origin (group name, room name, "
                    "or sender's display name).")),
        ),
        migrations.AddIndex(
            model_name="savedmaterial",
            index=models.Index(fields=["user", "subject"],
                               name="savedmat_user_subj_idx"),
        ),
        migrations.AddIndex(
            model_name="savedmaterial",
            index=models.Index(fields=["user", "source_group"],
                               name="savedmat_user_src_idx"),
        ),
    ]