# apps/studyhub/views.py
#
# The Study-Hub bridge API (spec phases 1-3): teacher office-hours availability,
# a shared Resource library (teacher upload / student browse / teacher verify),
# and a Q&A doubt board (ask / answer / resolve / upvote / accept). Role-aware:
# only teaching staff may upload resources, verify, or post a teacher-badged
# answer; any authenticated user may browse, ask, and answer as a peer.

import logging

from django.contrib.auth import get_user_model
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Answer, Question, Resource, TeacherAvailability

User = get_user_model()
logger = logging.getLogger(__name__)

# "Teacher" = anyone who can stand in front of a class: teaching staff + admins.
_TEACHER_ROLES = ("teaching_staff", "admin")


def _name(u):
    return (getattr(u, "display_name", "") or getattr(u, "name", "")
            or getattr(u, "preferred_name", "") or getattr(u, "username", "")
            or "User")


def _is_teacher(u):
    return bool(getattr(u, "is_superuser", False)) or \
        (getattr(u, "role", "") or "").lower() in _TEACHER_ROLES


# ── serializers (hand-rolled dicts) ──────────────────────────────────────
def _resource_dict(r, request):
    url = ""
    if r.file:
        try:
            url = request.build_absolute_uri(r.file.url)
        except Exception:
            url = r.file.url
    elif r.link_url:
        url = r.link_url
    return {
        "id":          str(r.id),
        "subject":     r.subject,
        "title":       r.title,
        "kind":        r.kind,
        "url":         url,
        "is_link":     bool(r.link_url and not r.file),
        "owner":       _name(r.owner),
        "verified":    r.verified_by_id is not None,
        "verified_by": _name(r.verified_by) if r.verified_by_id else "",
        "downloads":   r.downloads,
        "created_at":  r.created_at.isoformat(),
    }


def _answer_dict(a):
    return {
        "id":          str(a.id),
        "body":        a.body,
        "author":      _name(a.author),
        "is_teacher":  a.is_teacher,
        "is_accepted": a.is_accepted,
        "upvotes":     a.upvotes,
        "created_at":  a.created_at.isoformat(),
    }


def _question_dict(q, with_answers=False):
    d = {
        "id":          str(q.id),
        "subject":     q.subject,
        "title":       q.title,
        "body":        q.body,
        "status":      q.status,
        "asker":       _name(q.asker),
        "upvotes":     q.upvotes,
        "answer_count": q.answers.count(),
        "created_at":  q.created_at.isoformat(),
    }
    if with_answers:
        d["answers"] = [_answer_dict(a) for a in q.answers.all()]
    return d


# ── Resources ────────────────────────────────────────────────────────────
@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def resources(request):
    if request.method == "GET":
        qs = Resource.objects.select_related("owner", "verified_by").all()
        subject = request.query_params.get("subject")
        if subject:
            qs = qs.filter(subject__iexact=subject)
        kind = request.query_params.get("kind")
        if kind:
            qs = qs.filter(kind=kind)
        return Response({"results": [_resource_dict(r, request) for r in qs[:200]]})

    # POST — teacher upload only
    if not _is_teacher(request.user):
        return Response({"error": "Only teachers can share resources."}, status=403)

    title   = (request.data.get("title") or "").strip()
    subject = (request.data.get("subject") or "").strip()
    kind    = (request.data.get("kind") or "note").strip()
    link    = (request.data.get("link_url") or "").strip()
    upload  = request.FILES.get("file")

    if not title or not subject:
        return Response({"error": "Title and subject are required."}, status=400)
    if not upload and not link:
        return Response({"error": "Attach a file or provide a link."}, status=400)
    if kind not in dict(Resource.Kind.choices):
        kind = "link" if link and not upload else "note"

    r = Resource.objects.create(
        owner=request.user, subject=subject, title=title[:160],
        kind=kind, link_url=link, file=upload if upload else None,
    )
    return Response(_resource_dict(r, request), status=201)


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def resource_delete(request, pk):
    r = get_object_or_404(Resource, pk=pk)
    if r.owner_id != request.user.id and not _is_teacher(request.user):
        return Response({"error": "Not allowed."}, status=403)
    r.delete()
    return Response(status=204)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def resource_verify(request, pk):
    """Teacher endorses a resource as accurate — a trust signal in the library."""
    if not _is_teacher(request.user):
        return Response({"error": "Only teachers can verify resources."}, status=403)
    r = get_object_or_404(Resource, pk=pk)
    # Toggle: verify, or un-verify if this teacher already verified it.
    if r.verified_by_id == request.user.id:
        r.verified_by = None
    else:
        r.verified_by = request.user
    r.save(update_fields=["verified_by"])
    return Response(_resource_dict(r, request))


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def resource_download(request, pk):
    """Bump the download counter and hand back the URL."""
    r = get_object_or_404(Resource, pk=pk)
    Resource.objects.filter(pk=r.pk).update(downloads=r.downloads + 1)
    r.refresh_from_db(fields=["downloads"])
    return Response(_resource_dict(r, request))


# ── Q&A board ─────────────────────────────────────────────────────────────
@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def questions(request):
    if request.method == "GET":
        qs = Question.objects.prefetch_related("answers").all()
        subject = request.query_params.get("subject")
        if subject:
            qs = qs.filter(subject__iexact=subject)
        status_f = request.query_params.get("status")
        if status_f in ("open", "resolved"):
            qs = qs.filter(status=status_f)
        return Response({"results": [_question_dict(q) for q in qs[:200]]})

    title   = (request.data.get("title") or "").strip()
    subject = (request.data.get("subject") or "").strip()
    body    = (request.data.get("body") or "").strip()
    if not title or not subject:
        return Response({"error": "Title and subject are required."}, status=400)

    q = Question.objects.create(
        asker=request.user, subject=subject, title=title[:200], body=body)
    return Response(_question_dict(q, with_answers=True), status=201)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def question_detail(request, pk):
    q = get_object_or_404(Question.objects.prefetch_related("answers"), pk=pk)
    return Response(_question_dict(q, with_answers=True))


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def question_answer(request, pk):
    q = get_object_or_404(Question, pk=pk)
    body = (request.data.get("body") or "").strip()
    if not body:
        return Response({"error": "Answer cannot be empty."}, status=400)
    a = Answer.objects.create(
        question=q, author=request.user, body=body,
        is_teacher=_is_teacher(request.user))
    return Response(_answer_dict(a), status=201)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def question_resolve(request, pk):
    """Asker or any teacher can mark a question resolved (toggles)."""
    q = get_object_or_404(Question, pk=pk)
    if q.asker_id != request.user.id and not _is_teacher(request.user):
        return Response({"error": "Only the asker or a teacher can resolve this."},
                        status=403)
    q.status = "open" if q.status == "resolved" else "resolved"
    q.save(update_fields=["status"])
    return Response(_question_dict(q, with_answers=True))


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def question_upvote(request, pk):
    q = get_object_or_404(Question, pk=pk)
    uid = str(request.user.id)
    voters = list(q.voters or [])
    if uid in voters:
        voters.remove(uid)
    else:
        voters.append(uid)
    q.voters = voters
    q.upvotes = len(voters)
    q.save(update_fields=["voters", "upvotes"])
    return Response({"upvotes": q.upvotes, "voted": uid in voters})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def answer_accept(request, pk):
    """Asker or teacher marks one answer as the accepted one (exclusive)."""
    a = get_object_or_404(Answer.objects.select_related("question"), pk=pk)
    q = a.question
    if q.asker_id != request.user.id and not _is_teacher(request.user):
        return Response({"error": "Only the asker or a teacher can accept."}, status=403)
    Answer.objects.filter(question=q).update(is_accepted=False)
    a.is_accepted = True
    a.save(update_fields=["is_accepted"])
    if q.status != "resolved":
        q.status = "resolved"
        q.save(update_fields=["status"])
    return Response(_answer_dict(a))


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def answer_upvote(request, pk):
    a = get_object_or_404(Answer, pk=pk)
    uid = str(request.user.id)
    voters = list(a.voters or [])
    if uid in voters:
        voters.remove(uid)
    else:
        voters.append(uid)
    a.voters = voters
    a.upvotes = len(voters)
    a.save(update_fields=["voters", "upvotes"])
    return Response({"upvotes": a.upvotes, "voted": uid in voters})


# ── Office hours / availability ───────────────────────────────────────────
def _availability_dict(av):
    return {
        "teacher":    _name(av.teacher),
        "teacher_id": str(av.teacher_id),
        "subjects":   [s.strip() for s in (av.subjects or "").split(",") if s.strip()],
        "note":       av.note,
        "is_open":    av.is_open,
        "updated_at": av.updated_at.isoformat(),
    }


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def teachers(request):
    """GET: teachers currently open for help. POST: a teacher sets their own."""
    if request.method == "GET":
        qs = (TeacherAvailability.objects.select_related("teacher")
              .filter(is_open=True).order_by("-updated_at"))
        subject = request.query_params.get("subject")
        rows = [_availability_dict(a) for a in qs]
        if subject:
            s = subject.lower()
            rows = [r for r in rows if any(s in x.lower() for x in r["subjects"])]
        return Response({"results": rows})

    if not _is_teacher(request.user):
        return Response({"error": "Only teachers can set office hours."}, status=403)
    av, _ = TeacherAvailability.objects.get_or_create(teacher=request.user)
    av.subjects = (request.data.get("subjects") or av.subjects or "")[:200]
    av.note     = (request.data.get("note") or "")[:200]
    if "is_open" in request.data:
        av.is_open = str(request.data.get("is_open")).lower() in ("1", "true", "yes", "on")
    av.save()
    return Response(_availability_dict(av))


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def my_availability(request):
    """The signed-in teacher's own office-hours state (for the console)."""
    if not _is_teacher(request.user):
        return Response({"error": "Teachers only."}, status=403)
    av, _ = TeacherAvailability.objects.get_or_create(teacher=request.user)
    return Response(_availability_dict(av))
