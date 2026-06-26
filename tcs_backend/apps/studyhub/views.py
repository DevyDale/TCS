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

from django.db import transaction
from django.db.models import Count

from django.utils import timezone
from django.utils.dateparse import parse_datetime

from .models import (Answer, Question, Quiz, QuizAttempt, QuizQuestion,
                     Resource, SessionRSVP, StudySession, TeacherAvailability)

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


# ── Quizzes (spec §4) ─────────────────────────────────────────────────────
def _quiz_dict(q, *, include_answers=False, with_questions=False):
    d = {
        "id":           str(q.id),
        "subject":      q.subject,
        "title":        q.title,
        "description":  q.description,
        "source":       q.source,
        "is_published": q.is_published,
        "owner":        _name(q.owner),
        "owner_id":     str(q.owner_id),
        "time_limit_s": q.time_limit_s,
        "xp_reward":    q.xp_reward,
        "question_count": q.questions.count(),
        "created_at":   q.created_at.isoformat(),
    }
    if with_questions:
        d["questions"] = [_question_q_dict(qq, include_answers=include_answers)
                          for qq in q.questions.all()]
    return d


def _question_q_dict(qq, *, include_answers=False):
    d = {
        "id":      str(qq.id),
        "text":    qq.text,
        "options": qq.options,
        "order":   qq.order,
    }
    if include_answers:
        d["correct_index"] = qq.correct_index
        d["explanation"]   = qq.explanation
    return d


def _clean_questions_payload(raw):
    """Normalise an incoming questions list to MCQ rows. Returns list of dicts."""
    out = []
    for i, q in enumerate(raw or []):
        if not isinstance(q, dict):
            continue
        text = (q.get("text") or q.get("question") or "").strip()
        opts = q.get("options") or []
        if not text or not isinstance(opts, list) or len(opts) < 2:
            continue
        opts = [str(o).strip() for o in opts][:6]
        ci = q.get("correct_index")
        if ci is None and isinstance(q.get("correct_answer"), str):
            # map "A"/"B"/"C"/"D" -> index
            letter = q["correct_answer"].strip().upper()
            ci = "ABCDEF".find(letter) if letter in "ABCDEF" else 0
        try:
            ci = int(ci)
        except (TypeError, ValueError):
            ci = 0
        ci = max(0, min(ci, len(opts) - 1))
        out.append({
            "text": text[:1000], "options": opts, "correct_index": ci,
            "explanation": (q.get("explanation") or "").strip()[:500],
            "order": i,
        })
    return out


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def quiz_generate(request):
    """Dale drafts an MCQ set from a topic. Returns a DRAFT (not saved) for the
    teacher to review/edit before saving + publishing (the accuracy gate)."""
    if not _is_teacher(request.user):
        return Response({"error": "Only teachers can generate quizzes."}, status=403)
    topic = (request.data.get("topic") or "").strip()
    subject = (request.data.get("subject") or "").strip()
    if not topic:
        return Response({"error": "Give Dale a topic to build from."}, status=400)
    count = max(3, min(int(request.data.get("count") or 5), 15))
    difficulty = (request.data.get("difficulty") or "medium").lower()
    if difficulty not in ("easy", "medium", "hard"):
        difficulty = "medium"

    try:
        from apps.ai import ai_router
        from apps.quiz.services import _validate_questions, GenerationError
        sys = (
            "You are an expert academic quiz writer. Write multiple-choice "
            "questions on the given topic. Each question has exactly 4 options "
            "labelled A, B, C, D with one unambiguously correct answer and three "
            "plausible distractors. Include a brief explanation (<=30 words). "
            "Output ONLY valid JSON: "
            '{"questions":[{"id":"q1","type":"mcq","question":"...",'
            '"options":["..","..","..",".."],"correct_answer":"B","explanation":".."}]}'
        )
        user = (f"Topic: {topic}\n"
                f"{('Subject context: ' + subject) if subject else ''}\n"
                f"Generate exactly {count} multiple-choice questions at "
                f"{difficulty} difficulty.")
        result = ai_router.complete(
            "quiz",
            messages=[{"role": "system", "content": sys},
                      {"role": "user", "content": user}],
            max_tokens=2048, temperature=0.5,
            response_format={"type": "json_object"})
        raw = result.get("text") or ""
        if not raw:
            return Response({"error": result.get("error") or "Dale returned nothing."},
                            status=502)
        questions = _validate_questions(raw, max_q=count)
    except GenerationError as e:
        return Response({"error": str(e)}, status=502)
    except Exception as e:
        logger.exception("quiz generate failed")
        return Response({"error": f"Generation failed: {e}"}, status=502)

    # Map the quiz-service shape (correct_answer "A".."D") to our index form.
    drafts = []
    for i, q in enumerate(questions):
        if q.get("type") != "mcq":
            continue
        letter = str(q.get("correct_answer") or "A").upper()
        ci = "ABCD".find(letter)
        drafts.append({
            "text": q["question"], "options": q.get("options", []),
            "correct_index": ci if ci >= 0 else 0,
            "explanation": q.get("explanation", ""), "order": i,
        })
    return Response({"source": "ai", "subject": subject, "topic": topic,
                     "questions": drafts})


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def quizzes(request):
    if request.method == "GET":
        mine = request.query_params.get("mine") == "1"
        if mine:
            if not _is_teacher(request.user):
                return Response({"error": "Teachers only."}, status=403)
            qs = Quiz.objects.filter(owner=request.user)
        else:
            qs = Quiz.objects.filter(is_published=True)
            subject = request.query_params.get("subject")
            if subject:
                qs = qs.filter(subject__iexact=subject)
        qs = qs.prefetch_related("questions").select_related("owner")
        return Response({"results": [_quiz_dict(q) for q in qs[:200]]})

    # POST — create/save (teacher); may be a manual build or an edited AI draft
    if not _is_teacher(request.user):
        return Response({"error": "Only teachers can create quizzes."}, status=403)
    title   = (request.data.get("title") or "").strip()
    subject = (request.data.get("subject") or "").strip()
    if not title or not subject:
        return Response({"error": "Title and subject are required."}, status=400)
    questions = _clean_questions_payload(request.data.get("questions"))
    if not questions:
        return Response({"error": "Add at least one valid question."}, status=400)

    with transaction.atomic():
        quiz = Quiz.objects.create(
            owner=request.user, title=title[:160], subject=subject,
            description=(request.data.get("description") or "")[:300],
            source=("ai" if request.data.get("source") == "ai" else "manual"),
            time_limit_s=request.data.get("time_limit_s") or None,
            xp_reward=max(0, min(int(request.data.get("xp_reward") or 20), 200)),
            is_published=False)
        QuizQuestion.objects.bulk_create([
            QuizQuestion(quiz=quiz, text=q["text"], options=q["options"],
                         correct_index=q["correct_index"],
                         explanation=q["explanation"], order=q["order"])
            for q in questions])
    return Response(_quiz_dict(quiz, with_questions=True, include_answers=True),
                    status=201)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def quiz_detail(request, pk):
    q = get_object_or_404(Quiz.objects.prefetch_related("questions"), pk=pk)
    is_owner = q.owner_id == request.user.id
    if not q.is_published and not is_owner and not _is_teacher(request.user):
        return Response({"error": "This quiz isn't published yet."}, status=403)
    # Owners/teachers see answers (to review); students take it blind.
    show = is_owner or _is_teacher(request.user)
    return Response(_quiz_dict(q, with_questions=True, include_answers=show))


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def quiz_publish(request, pk):
    q = get_object_or_404(Quiz, pk=pk)
    if q.owner_id != request.user.id and not _is_teacher(request.user):
        return Response({"error": "Not allowed."}, status=403)
    if not q.questions.exists():
        return Response({"error": "Add questions before publishing."}, status=400)
    q.is_published = not q.is_published   # toggle (unpublish to revise)
    q.save(update_fields=["is_published"])
    return Response(_quiz_dict(q))


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def quiz_delete(request, pk):
    q = get_object_or_404(Quiz, pk=pk)
    if q.owner_id != request.user.id and not _is_teacher(request.user):
        return Response({"error": "Not allowed."}, status=403)
    q.delete()
    return Response(status=204)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def quiz_attempt(request, pk):
    """Auto-grade an attempt. First-ever attempt awards XP/tokens (anti-farm)."""
    q = get_object_or_404(Quiz.objects.prefetch_related("questions"), pk=pk)
    if not q.is_published and q.owner_id != request.user.id:
        return Response({"error": "This quiz isn't published yet."}, status=403)
    answers = request.data.get("answers") or {}
    if not isinstance(answers, dict):
        return Response({"error": "answers must be an object."}, status=400)

    qns = list(q.questions.all())
    correct = 0
    review = []
    for qq in qns:
        chosen = answers.get(str(qq.id))
        try:
            chosen = int(chosen)
        except (TypeError, ValueError):
            chosen = -1
        ok = chosen == qq.correct_index
        if ok:
            correct += 1
        review.append({
            "id": str(qq.id), "chosen": chosen,
            "correct_index": qq.correct_index, "is_correct": ok,
            "explanation": qq.explanation})

    total = len(qns)
    first_time = not QuizAttempt.objects.filter(quiz=q, user=request.user).exists()
    xp = 0
    if first_time and total and q.xp_reward:
        xp = round(q.xp_reward * correct / total)

    attempt = QuizAttempt.objects.create(
        quiz=q, user=request.user, score=correct, total=total,
        answers={str(k): v for k, v in answers.items()}, xp_awarded=xp)

    if xp > 0:
        try:
            from apps.arcade.services import credit
            with transaction.atomic():
                credit(request.user, xp, reason="studyhub_quiz",
                       reference_type="studyhub_quiz", reference_id=str(q.id))
        except Exception:
            logger.exception("quiz XP award failed (non-fatal)")

    return Response({
        "attempt_id": str(attempt.id),
        "score": correct, "total": total,
        "percentage": round(100 * correct / total) if total else 0,
        "xp_awarded": xp, "review": review,
    }, status=201)


# ── Study Sessions (spec §3E) ─────────────────────────────────────────────
def _session_dict(s, user):
    rsvps = list(s.rsvps.all())
    return {
        "id":          str(s.id),
        "subject":     s.subject,
        "title":       s.title,
        "description": s.description,
        "when":        s.when.isoformat(),
        "location":    s.location,
        "link":        s.link,
        "teacher":     _name(s.teacher),
        "teacher_id":  str(s.teacher_id),
        "rsvp_count":  len(rsvps),
        "is_rsvped":   any(r.user_id == user.id for r in rsvps),
        "is_mine":     s.teacher_id == user.id,
        "created_at":  s.created_at.isoformat(),
    }


def _notify_session_audience(session, actor, *, title, body):
    """Fan a study-session notice to students (in-app + FCM). Tapping opens the
    session (target_type=study_session). Mirrors the events fan-out."""
    try:
        from apps.notifications.tasks import _create, _fcm_send_multi
        qs = User.objects.filter(is_active=True, role="student").exclude(id=actor.id)
        toks = []
        for u in qs.iterator():
            try:
                _create(str(u.id), str(actor.id), "study_session", title, body,
                        "study_session", str(session.id))
                tk = getattr(u, "fcm_token", "") or ""
                if tk:
                    toks.append(tk)
            except Exception:
                pass
        if toks:
            _fcm_send_multi(toks, title, body,
                            data={"type": "study_session", "id": str(session.id)})
    except Exception:
        logger.exception("study-session notify failed")


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def sessions(request):
    if request.method == "GET":
        # Upcoming by default; ?when=past for history, ?mine=1 for own/RSVP'd.
        qs = StudySession.objects.select_related("teacher").prefetch_related("rsvps")
        when = request.query_params.get("when", "upcoming")
        now = timezone.now()
        if when == "past":
            qs = qs.filter(when__lt=now).order_by("-when")
        else:
            qs = qs.filter(when__gte=now - timezone.timedelta(hours=2)).order_by("when")
        if request.query_params.get("mine") == "1":
            if _is_teacher(request.user):
                qs = qs.filter(teacher=request.user)
            else:
                qs = qs.filter(rsvps__user=request.user)
        subject = request.query_params.get("subject")
        if subject:
            qs = qs.filter(subject__iexact=subject)
        return Response({"results": [_session_dict(s, request.user) for s in qs[:200]]})

    # POST — schedule (teacher)
    if not _is_teacher(request.user):
        return Response({"error": "Only teachers can schedule sessions."}, status=403)
    title   = (request.data.get("title") or "").strip()
    subject = (request.data.get("subject") or "").strip()
    when    = (request.data.get("when") or "").strip()
    if not title or not subject or not when:
        return Response({"error": "Title, subject and time are required."}, status=400)
    dt = parse_datetime(when)
    if dt is None:
        return Response({"error": "Invalid time format."}, status=400)
    if timezone.is_naive(dt):
        dt = timezone.make_aware(dt, timezone.get_current_timezone())

    s = StudySession.objects.create(
        teacher=request.user, subject=subject, title=title[:160],
        description=(request.data.get("description") or "")[:400],
        when=dt, location=(request.data.get("location") or "")[:160],
        link=(request.data.get("link") or "")[:200])
    if str(request.data.get("notify")).lower() in ("1", "true", "yes", "on"):
        _notify_session_audience(s, request.user,
                                 title="📚 New study session",
                                 body=f"{s.subject}: {s.title}")
    return Response(_session_dict(s, request.user), status=201)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def session_rsvp(request, pk):
    s = get_object_or_404(StudySession, pk=pk)
    rsvp = SessionRSVP.objects.filter(session=s, user=request.user).first()
    if rsvp:
        rsvp.delete()
        going = False
    else:
        SessionRSVP.objects.get_or_create(session=s, user=request.user)
        going = True
    return Response({"is_rsvped": going, "rsvp_count": s.rsvps.count()})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def session_remind(request, pk):
    """Teacher fans a reminder to everyone who has RSVP'd (spec §3E)."""
    s = get_object_or_404(StudySession, pk=pk)
    if s.teacher_id != request.user.id and not _is_teacher(request.user):
        return Response({"error": "Not allowed."}, status=403)
    try:
        from apps.notifications.tasks import _create, _fcm_send_multi
        attendees = User.objects.filter(session_rsvps__session=s, is_active=True).distinct()
        title = "⏰ Study session reminder"
        body = f"{s.subject}: {s.title}"
        toks = []
        for u in attendees:
            try:
                _create(str(u.id), str(request.user.id), "study_session", title, body,
                        "study_session", str(s.id))
                tk = getattr(u, "fcm_token", "") or ""
                if tk:
                    toks.append(tk)
            except Exception:
                pass
        if toks:
            _fcm_send_multi(toks, title, body,
                            data={"type": "study_session", "id": str(s.id)})
        return Response({"reminded": attendees.count()})
    except Exception:
        logger.exception("session remind failed")
        return Response({"error": "Could not send reminders."}, status=500)


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def session_delete(request, pk):
    s = get_object_or_404(StudySession, pk=pk)
    if s.teacher_id != request.user.id and not _is_teacher(request.user):
        return Response({"error": "Not allowed."}, status=403)
    s.delete()
    return Response(status=204)


# ── Demand Insights (spec §5 — aggregate only, no individual singled out) ──
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def insights(request):
    """Teacher-only aggregate of where demand is: which subjects students ask
    about most, what's unanswered, hardest quiz questions, and coverage gaps.
    Everything here is counts by subject — never a named student."""
    if not _is_teacher(request.user):
        return Response({"error": "Teachers only."}, status=403)

    from collections import defaultdict

    # Per-subject rollup across questions / resources / sessions.
    by_subject = defaultdict(lambda: {
        "subject": "", "questions": 0, "open_questions": 0,
        "resources": 0, "sessions": 0})

    def _norm(s):
        return (s or "").strip()

    for q in Question.objects.all().only("subject", "status"):
        key = _norm(q.subject).lower()
        if not key:
            continue
        row = by_subject[key]
        row["subject"] = row["subject"] or _norm(q.subject)
        row["questions"] += 1
        if q.status == "open":
            row["open_questions"] += 1

    for r in Resource.objects.all().only("subject"):
        key = _norm(r.subject).lower()
        if not key:
            continue
        row = by_subject[key]
        row["subject"] = row["subject"] or _norm(r.subject)
        row["resources"] += 1

    for s in StudySession.objects.all().only("subject"):
        key = _norm(s.subject).lower()
        if not key:
            continue
        row = by_subject[key]
        row["subject"] = row["subject"] or _norm(s.subject)
        row["sessions"] += 1

    rows = list(by_subject.values())
    # Demand score: open questions weigh most, then total questions, minus the
    # resources already covering them. Surfaces where students need more help.
    for r in rows:
        r["demand"] = r["open_questions"] * 3 + r["questions"] - r["resources"]
    top_subjects = sorted(rows, key=lambda r: (-r["open_questions"], -r["questions"]))[:12]

    # Coverage gaps: students are asking but there's little/no curated material.
    gaps = sorted(
        [r for r in rows if r["questions"] >= 2 and r["resources"] == 0],
        key=lambda r: -r["questions"])[:8]

    # Unanswered: open questions with zero answers — the most acute backlog.
    unanswered = (Question.objects.filter(status="open")
                  .annotate(n=Count("answers")).filter(n=0).count())

    # Hardest quiz questions across PUBLISHED quizzes — cohort misconceptions.
    hardest = []
    for qq in (QuizQuestion.objects
               .filter(quiz__is_published=True)
               .select_related("quiz")[:500]):
        attempts = QuizAttempt.objects.filter(quiz=qq.quiz)
        answered = missed = 0
        for a in attempts.only("answers"):
            ans = a.answers or {}
            if str(qq.id) in ans:
                answered += 1
                try:
                    if int(ans[str(qq.id)]) != qq.correct_index:
                        missed += 1
                except (TypeError, ValueError):
                    missed += 1
        if answered >= 1:
            hardest.append({
                "subject": qq.quiz.subject, "text": qq.text,
                "answered": answered, "missed": missed,
                "miss_rate": round(100 * missed / answered)})
    hardest = sorted(hardest, key=lambda h: -h["miss_rate"])[:8]

    return Response({
        "totals": {
            "subjects":        len([r for r in rows if r["questions"] or r["resources"]]),
            "questions":       Question.objects.count(),
            "open_questions":  Question.objects.filter(status="open").count(),
            "unanswered":      unanswered,
            "resources":       Resource.objects.count(),
            "upcoming_sessions": StudySession.objects.filter(
                when__gte=timezone.now()).count(),
        },
        "top_subjects": top_subjects,
        "coverage_gaps": gaps,
        "hardest_questions": hardest,
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def quiz_analytics(request, pk):
    """Teacher view: attempts, average score, hardest questions (spec §4)."""
    q = get_object_or_404(Quiz.objects.prefetch_related("questions"), pk=pk)
    if q.owner_id != request.user.id and not _is_teacher(request.user):
        return Response({"error": "Teachers only."}, status=403)

    attempts = list(q.attempts.all())
    n = len(attempts)
    avg = round(sum(100 * a.score / a.total for a in attempts if a.total) / n) if n else 0

    # Per-question miss rate, only counting attempts that answered it.
    rows = []
    for qq in q.questions.all():
        answered = missed = 0
        for a in attempts:
            if str(qq.id) in (a.answers or {}):
                answered += 1
                try:
                    if int(a.answers[str(qq.id)]) != qq.correct_index:
                        missed += 1
                except (TypeError, ValueError):
                    missed += 1
        rows.append({
            "id": str(qq.id), "text": qq.text,
            "answered": answered, "missed": missed,
            "miss_rate": round(100 * missed / answered) if answered else 0,
        })
    rows.sort(key=lambda r: r["miss_rate"], reverse=True)
    return Response({
        "attempts": n, "average_score": avg,
        "question_count": q.questions.count(), "hardest": rows,
    })
