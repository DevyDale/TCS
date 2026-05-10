import uuid
from django.db import models
from django.conf import settings


class MediaAsset(models.Model):
    class AssetType(models.TextChoices):
        IMAGE = "image", "Image"
        VIDEO = "video", "Video"
        AUDIO = "audio", "Audio"
        GIF   = "gif",   "GIF"
        FILE  = "file",  "File"

    id            = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    uploaded_by   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                       related_name="media_assets")
    file          = models.FileField(upload_to="assets/%Y/%m/%d/")
    asset_type    = models.CharField(max_length=10, choices=AssetType.choices)
    mime_type     = models.CharField(max_length=80)
    file_size     = models.PositiveBigIntegerField()
    original_name = models.CharField(max_length=260)
    created_at    = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "media_assets"
        ordering = ["-created_at"]
