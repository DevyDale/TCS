# apps/ai/knowledge_views.py
#
# Staff-facing knowledge base management: train Dale from a PDF/DOCX, a web
# link, or an audio/video recording (transcribed) — extracted + chunked on
# upload. List docs, toggle active, delete. Active docs feed Dale's RAG via
# knowledge.retrieve_context().

import re
from html import unescape

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response

from apps.accounts.permissions import IsStaff
from .knowledge import bump_kb_version, ingest_text
from .models import KnowledgeChunk, KnowledgeDoc

# Media Groq's whisper-large-v3 accepts (audio + video containers).
MEDIA_EXTS = (".mp3", ".wav", ".m4a", ".webm", ".ogg", ".oga",
              ".mp4", ".mpeg", ".mpga", ".flac")


def _strip_html(html: str) -> str:
    """Best-effort readable text from a web page — no external deps."""
    html = re.sub(r"(?is)<(script|style|noscript|head|nav|footer|svg)[^>]*>.*?</\1>", " ", html)
    html = re.sub(r"(?s)<!--.*?-->", " ", html)
    html = re.sub(r"(?s)<[^>]+>", " ", html)
    return re.sub(r"\s+", " ", unescape(html)).strip()


def _fetch_url_text(url: str) -> str:
    """Fetch a web link and return its readable text."""
    import requests
    if not re.match(r"^https?://", url, re.I):
        url = "https://" + url
    try:
        resp = requests.get(url, timeout=25,
                            headers={"User-Agent": "Mozilla/5.0 (compatible; TCS-Dale/1.0)"})
        resp.raise_for_status()
    except Exception:
        raise ValueError("Couldn’t reach that link.")
    ctype = (resp.headers.get("Content-Type") or "").lower()
    body = resp.text or ""
    if len(body) > 8_000_000:
        body = body[:8_000_000]
    head = body[:3000].lower()
    if ("html" in ctype or "<html" in head or "<body" in head
            or "<!doctype html" in head):
        return _strip_html(body)
    if "text" in ctype or "json" in ctype or ctype == "":
        return re.sub(r"\s+", " ", body).strip()
    raise ValueError("That link isn’t a readable web page (upload files directly).")


def _youtube_id(url: str):
    """Pull the 11-char video id out of any common YouTube URL shape."""
    m = re.search(r"(?:youtu\.be/|youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|embed/|live/|v/))([A-Za-z0-9_-]{11})", url)
    return m.group(1) if m else None


def _youtube_transcript(video_id: str) -> str:
    """Fetch a YouTube video's transcript (captions). Works across the 0.6.x
    and 1.x youtube-transcript-api APIs."""
    try:
        from youtube_transcript_api import YouTubeTranscriptApi
    except Exception:
        raise ValueError("YouTube transcripts aren’t available on this server.")
    langs = ["en", "en-US", "en-GB", "en-AU"]
    segs = None
    try:
        segs = YouTubeTranscriptApi.get_transcript(video_id, languages=langs)  # 0.6.x
    except AttributeError:
        try:
            fetched = YouTubeTranscriptApi().fetch(video_id, languages=langs)  # 1.x
            segs = fetched.to_raw_data() if hasattr(fetched, "to_raw_data") else list(fetched)
        except Exception:
            raise ValueError("Couldn’t fetch this video’s transcript.")
    except Exception:
        raise ValueError("This video has no usable captions (or they’re disabled).")
    parts = []
    for s in (segs or []):
        parts.append(s.get("text", "") if isinstance(s, dict) else getattr(s, "text", ""))
    text = re.sub(r"\s+", " ", " ".join(parts)).strip()
    if not text:
        raise ValueError("This video has no captions to learn from.")
    return text


def _ingest_url_text(url: str) -> str:
    """Route a link to the right extractor: YouTube → captions, else page text."""
    vid = _youtube_id(url)
    return _youtube_transcript(vid) if vid else _fetch_url_text(url)


def _transcribe_media(data: bytes, filename: str) -> str:
    """Transcribe an audio/video recording via Groq whisper-large-v3."""
    import requests
    from .ai_router import key_for
    key = key_for("groq")
    if not key:
        raise ValueError("Speech transcription isn’t configured on this server.")
    try:
        resp = requests.post(
            "https://api.groq.com/openai/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {key}"},
            files={"file": (filename or "recording", data)},
            data={"model": "whisper-large-v3", "response_format": "text"},
            timeout=240,
        )
    except Exception:
        raise ValueError("Couldn’t reach the transcription service.")
    if resp.status_code != 200:
        raise ValueError("Couldn’t transcribe this recording.")
    return (resp.text or "").strip()


def _doc_dict(d):
    return {
        "id":          str(d.id),
        "title":       d.title,
        "subject":     d.subject,
        "filename":    d.filename,
        "char_count":  d.char_count,
        "chunk_count": d.chunk_count,
        "is_active":   d.is_active,
        "uploaded_by": getattr(d.uploaded_by, "display_name", "") or "",
        "created_at":  d.created_at.isoformat(),
        "retrieval_count":   d.retrieval_count,
        "last_retrieved_at": d.last_retrieved_at.isoformat()
                             if d.last_retrieved_at else None,
    }


@api_view(["GET"])
@permission_classes([IsStaff])
def knowledge_list(request):
    docs = list(KnowledgeDoc.objects.select_related("uploaded_by").all()[:200])
    return Response({
        "results":       [_doc_dict(d) for d in docs],
        "active_chunks": sum(d.chunk_count for d in docs if d.is_active),
    })


@api_view(["POST"])
@permission_classes([IsStaff])
@parser_classes([MultiPartParser, FormParser])
def knowledge_upload(request):
    f = request.FILES.get("file")
    if not f:
        return Response({"error": "A file is required."}, status=400)
    title   = (request.data.get("title") or "").strip() or f.name
    subject = (request.data.get("subject") or "").strip()

    from apps.quiz.services import (ExtractionError, extract_text_from_docx,
                                    extract_text_from_pdf)
    data = f.read()
    name = (f.name or "").lower()
    is_media = name.endswith(MEDIA_EXTS)
    try:
        if name.endswith(".pdf"):
            text = extract_text_from_pdf(data)
        elif name.endswith((".docx", ".doc")):
            text = extract_text_from_docx(data)
        elif is_media:
            text = _transcribe_media(data, f.name)
        else:
            return Response({"error": "Supported: PDF, DOCX, or an audio/video "
                                      "recording (mp3, m4a, wav, mp4…)."}, status=400)
    except (ExtractionError, ValueError) as e:
        return Response({"error": str(e)}, status=400)

    # A transcript can legitimately be short (a quick spoken note); a document
    # that yields almost nothing is usually a scan or an error.
    if len((text or "").strip()) < (15 if is_media else 100):
        return Response({"error": "Not enough readable content to train on."}, status=400)

    doc = KnowledgeDoc.objects.create(
        title=str(title)[:200], subject=subject[:80],
        filename=(f.name or "")[:255], uploaded_by=request.user)
    ingest_text(doc, text)
    bump_kb_version()
    doc.refresh_from_db()
    return Response(_doc_dict(doc), status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([IsStaff])
@parser_classes([JSONParser, FormParser, MultiPartParser])
def knowledge_upload_url(request):
    """Train Dale from a web link — the server fetches the page and extracts
    its readable text. POST { url, title?, subject? }."""
    url = (request.data.get("url") or "").strip()
    if not url:
        return Response({"error": "A link is required."}, status=400)
    title   = (request.data.get("title") or "").strip() or url
    subject = (request.data.get("subject") or "").strip()
    try:
        text = _ingest_url_text(url)
    except ValueError as e:
        return Response({"error": str(e)}, status=400)
    if len((text or "").strip()) < 100:
        return Response({"error": "That link didn’t have enough readable text."}, status=400)

    doc = KnowledgeDoc.objects.create(
        title=str(title)[:200], subject=subject[:80],
        filename=url[:255], uploaded_by=request.user)
    ingest_text(doc, text)
    bump_kb_version()
    doc.refresh_from_db()
    return Response(_doc_dict(doc), status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([IsStaff])
def knowledge_analytics(request):
    """Training analytics for the Dale knowledge base: totals, who trained it
    last + what they added, a recent training-activity feed, and usage — how
    often Dale has actually drawn on each material to answer students."""
    docs = list(KnowledgeDoc.objects.select_related("uploaded_by")
                .order_by("-created_at")[:200])

    active = [d for d in docs if d.is_active]
    contributors = {d.uploaded_by_id for d in docs if d.uploaded_by_id}
    total_retrievals = sum(d.retrieval_count for d in docs)

    def _name(d):
        return getattr(d.uploaded_by, "display_name", "") or "Staff"

    def _activity(d):
        return {
            "id":          str(d.id),
            "title":       d.title,
            "subject":     d.subject,
            "by":          _name(d),
            "chunk_count": d.chunk_count,
            "char_count":  d.char_count,
            "is_active":   d.is_active,
            "created_at":  d.created_at.isoformat(),
        }

    last = docs[0] if docs else None
    # Most-used materials (how Dale has responded with the trained content).
    most_used = sorted([d for d in docs if d.retrieval_count > 0],
                       key=lambda d: d.retrieval_count, reverse=True)[:5]

    return Response({
        "totals": {
            "documents":     len(docs),
            "active":        len(active),
            "active_chunks": sum(d.chunk_count for d in active),
            "total_chars":   sum(d.char_count for d in docs),
            "contributors":  len(contributors),
            "retrievals":    total_retrievals,
        },
        "last_trained": _activity(last) if last else None,
        "recent": [_activity(d) for d in docs[:10]],
        "most_used": [{
            "id":                str(d.id),
            "title":             d.title,
            "by":                _name(d),
            "retrieval_count":   d.retrieval_count,
            "last_retrieved_at": d.last_retrieved_at.isoformat()
                                 if d.last_retrieved_at else None,
        } for d in most_used],
    })


@api_view(["GET"])
@permission_classes([IsStaff])
def knowledge_chunks(request, pk):
    """Preview the passages Dale actually learned from a document."""
    d = KnowledgeDoc.objects.filter(id=pk).first()
    if not d:
        return Response({"error": "Not found."}, status=404)
    chunks = KnowledgeChunk.objects.filter(doc=d).order_by("ordinal")[:60]
    return Response({
        "id":       str(d.id),
        "title":    d.title,
        "subject":  d.subject,
        "chunks":   [{"ordinal": c.ordinal, "content": c.content} for c in chunks],
    })


@api_view(["POST"])
@permission_classes([IsStaff])
def knowledge_toggle(request, pk):
    d = KnowledgeDoc.objects.filter(id=pk).first()
    if not d:
        return Response({"error": "Not found."}, status=404)
    d.is_active = not d.is_active
    d.save(update_fields=["is_active"])
    bump_kb_version()
    return Response(_doc_dict(d))


@api_view(["DELETE"])
@permission_classes([IsStaff])
def knowledge_delete(request, pk):
    d = KnowledgeDoc.objects.filter(id=pk).first()
    if not d:
        return Response({"error": "Not found."}, status=404)
    d.delete()  # cascades chunks
    bump_kb_version()
    return Response(status=status.HTTP_204_NO_CONTENT)
