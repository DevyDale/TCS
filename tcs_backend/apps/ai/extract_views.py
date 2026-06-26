# apps/ai/extract_views.py
#
# Pull plain text out of an uploaded PDF / DOCX / TXT so the assistant can act
# on it (translate a notice, summarise a policy, …). Reuses the same extractors
# the quiz + knowledge-base features use. Any authenticated user may call it —
# the attach button lives in the shared AI assistant.

from rest_framework.decorators import (api_view, parser_classes,
                                        permission_classes)
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

MAX_CHARS = 8000  # keep within the chat model's input budget


@api_view(["POST"])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def extract_document(request):
    f = request.FILES.get("file")
    if not f:
        return Response({"error": "A file is required."}, status=400)

    from apps.quiz.services import (ExtractionError, extract_text_from_docx,
                                    extract_text_from_pdf)
    data = f.read()
    name = (f.name or "").lower()
    try:
        if name.endswith(".pdf"):
            text = extract_text_from_pdf(data)
        elif name.endswith((".docx", ".doc")):
            text = extract_text_from_docx(data)
        elif name.endswith((".txt", ".md", ".csv")):
            text = data.decode("utf-8", errors="ignore")
        else:
            return Response(
                {"error": "Unsupported file. Use a PDF, DOCX or TXT."},
                status=400)
    except ExtractionError as e:
        return Response({"error": str(e)}, status=400)
    except Exception:
        return Response({"error": "Could not read that file."}, status=400)

    text = (text or "").strip()
    if not text:
        return Response(
            {"error": "No readable text found in that file."}, status=400)

    return Response({
        "text": text[:MAX_CHARS],
        "truncated": len(text) > MAX_CHARS,
        "filename": f.name,
    })
