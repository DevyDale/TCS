from django.contrib import admin
from .models import MediaAsset


@admin.register(MediaAsset)
class MediaAssetAdmin(admin.ModelAdmin):
    list_display  = ["id", "uploaded_by", "asset_type", "original_name",
                     "file_size", "created_at"]
    list_filter   = ["asset_type"]
    search_fields = ["original_name", "uploaded_by__name"]
    readonly_fields = ["id", "created_at"]
