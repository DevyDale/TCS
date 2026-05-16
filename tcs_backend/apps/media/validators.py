"""
File upload validators for the media app.
Reconstructed from compiled bytecode after originals were accidentally overwritten.
Verify against your views/serializers — minor adjustments may be needed.
"""
import magic
import mimetypes
from django.conf import settings


# Allowed MIME types -> message_type used by chat/posts/etc.
MIME_MAP = {
    "image/jpeg": "image",
    "image/png":  "image",
    "image/webp": "image",
    "image/gif":  "gif",
    "video/mp4":        "video",
    "video/webm":       "video",
    "video/quicktime":  "video",
    "audio/mpeg": "audio",
    "audio/ogg":  "audio",
    "audio/wav":  "audio",
    "audio/aac":  "audio",
    "audio/mp4":  "audio",
    "application/pdf":  "file",
    "application/zip":  "file",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "file",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":       "file",
    "audio/x-m4a": "audio",
    "audio/m4a":   "audio",
    "audio/mp3":   "audio",
    "audio/x-wav": "audio",
    "audio/webm":  "audio",
    "audio/3gpp":  "audio",
}


SIZE_LIMITS = {
    "image": getattr(settings, "MAX_IMAGE_MB", 10),
    "gif":   getattr(settings, "MAX_IMAGE_MB", 10),
    "video": getattr(settings, "MAX_VIDEO_MB", 100),
    "audio": getattr(settings, "MAX_AUDIO_MB", 25),
    "file":  getattr(settings, "MAX_FILE_MB",  25),
}


def validate_file(file):
    """
    Validate uploaded file.
    Returns {mime, message_type} or raises ValueError.
    """
    # Detect MIME from first 2KB of content via libmagic
    try:
        mime = magic.from_buffer(file.read(2048), mime=True)
        file.seek(0)
    except Exception:
        guessed, _ = mimetypes.guess_type(getattr(file, "name", "") or "")
        mime = guessed or getattr(file, "content_type", None) or "application/octet-stream"

    if mime not in MIME_MAP:
        raise ValueError(f"File type '{mime}' is not allowed.")

    message_type = MIME_MAP[mime]
    max_mb = SIZE_LIMITS.get(message_type, 25)

    size_mb = getattr(file, "size", 0) / (1024 * 1024)
    if size_mb > max_mb:
        raise ValueError(
            f"{message_type.title()} must be under {max_mb} MB. "
            f"Yours is {size_mb:.2f} MB."
        )

    return {"mime": mime, "message_type": message_type}
