# apps/ai/knowledge.py
#
# RAG knowledge base. Staff upload PDFs/DOCXs; text is extracted, chunked, and
# stored. retrieve_context() runs on-the-fly Postgres full-text search over
# active chunks and returns the most relevant text to inject into Dale's prompt.
#
# Free by design — keyword full-text search, no embeddings/vector DB. The
# upgrade path is NVIDIA's baai/bge-m3 for semantic retrieval (later phase).

import hashlib
import logging
import re

from django.contrib.postgres.search import SearchQuery, SearchRank, SearchVector
from django.core.cache import cache

from .models import KnowledgeChunk

logger = logging.getLogger(__name__)

_RETRIEVE_TTL = 300  # cache a query's retrieved context for 5 min


def kb_version():
    """A counter bumped whenever the knowledge base changes — folded into the
    retrieval cache key so an upload/toggle/delete invalidates cached lookups."""
    return cache.get("ai_kb_version", 0)


def bump_kb_version():
    try:
        cache.incr("ai_kb_version")
    except ValueError:
        cache.set("ai_kb_version", 1)

_CHUNK_CHARS   = 900
_CHUNK_OVERLAP = 120


def _chunk_text(text, size=_CHUNK_CHARS, overlap=_CHUNK_OVERLAP):
    text = re.sub(r"\n{3,}", "\n\n", (text or "").strip())
    if not text:
        return []
    paras = [p.strip() for p in text.split("\n\n") if p.strip()]
    chunks, cur = [], ""
    for p in paras:
        if len(cur) + len(p) + 2 <= size:
            cur = (cur + "\n\n" + p).strip()
            continue
        if cur:
            chunks.append(cur)
            cur = ""
        if len(p) <= size:
            cur = p
        else:  # hard-split an oversized paragraph, with overlap
            step = max(1, size - overlap)
            for i in range(0, len(p), step):
                chunks.append(p[i:i + size])
    if cur:
        chunks.append(cur)
    return chunks


def ingest_text(doc, text):
    """Replace a doc's chunks with freshly-chunked text. Returns chunk count."""
    KnowledgeChunk.objects.filter(doc=doc).delete()
    chunks = _chunk_text(text)
    KnowledgeChunk.objects.bulk_create(
        [KnowledgeChunk(doc=doc, ordinal=i, content=c) for i, c in enumerate(chunks)],
        batch_size=200,
    )
    doc.char_count  = len(text or "")
    doc.chunk_count = len(chunks)
    doc.save(update_fields=["char_count", "chunk_count"])
    return len(chunks)


def retrieve_context(query, limit=4, max_chars=2200):
    """Top relevant chunks across all ACTIVE docs, concatenated. "" if none.

    Called on every Dale chat turn; must be cheap and never raise into the
    request path (any failure → empty context, chat proceeds without RAG).
    """
    q = (query or "").strip()
    if not q:
        return ""

    ckey = "ai_kb_ret_%s_%s" % (kb_version(),
                                hashlib.md5(q.lower().encode("utf-8")).hexdigest())
    try:
        hit = cache.get(ckey)
        if hit is not None:
            return hit
    except Exception:
        pass

    try:
        rows = (KnowledgeChunk.objects
                .filter(doc__is_active=True)
                .annotate(rank=SearchRank(SearchVector("content"),
                                          SearchQuery(q, search_type="websearch")))
                .filter(rank__gt=0)
                .order_by("-rank")[:limit])
        out, total = [], 0
        for c in rows:
            out.append(c.content)
            total += len(c.content)
            if total >= max_chars:
                break
        result = "\n\n".join(out)
        try:
            cache.set(ckey, result, _RETRIEVE_TTL)
        except Exception:
            pass
        return result
    except Exception as e:  # noqa: BLE001 — never break chat over retrieval
        logger.warning("retrieve_context failed: %s", e)
        return ""
