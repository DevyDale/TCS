# apps/ai/knowledge_views.py
#
# Staff-facing knowledge base management: upload a PDF/DOCX (extracted +
# chunked on upload), list docs, toggle active, delete. Active docs feed
# Dale's RAG via knowledge.retrieve_context().

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from apps.accounts.permissions import IsStaff
from .knowledge import bump_kb_version, ingest_text
from .models import KnowledgeChunk, KnowledgeDoc


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
    try:
        if name.endswith(".pdf"):
            text = extract_text_from_pdf(data)
        elif name.endswith((".docx", ".doc")):
            text = extract_text_from_docx(data)
        else:
            return Response({"error": "Only PDF and DOCX files are supported."}, status=400)
    except ExtractionError as e:
        return Response({"error": str(e)}, status=400)

    if len((text or "").strip()) < 100:
        return Response({"error": "Not enough readable text in this file."}, status=400)

    doc = KnowledgeDoc.objects.create(
        title=str(title)[:200], subject=subject[:80],
        filename=(f.name or "")[:255], uploaded_by=request.user)
    ingest_text(doc, text)
    bump_kb_version()
    doc.refresh_from_db()
    return Response(_doc_dict(doc), status=status.HTTP_201_CREATED)


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
