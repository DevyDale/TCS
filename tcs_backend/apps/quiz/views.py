# apps/quiz/views.py
from datetime import timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.chat.models import SavedMaterial

from .models import GeneratedQuiz, QuizAttempt
from .serializers import (QuizAttemptSerializer, QuizDetailSerializer,
                          QuizListItemSerializer, QuizPlaySerializer)
from .services import (ExtractionError, FileFetchError, GenerationError,
                       generate_quiz_from_material, grade_attempt)


# How many quizzes a single user can generate per rolling 24h window.
DAILY_GEN_LIMIT = 20


# ─────────────────────────────────────────────────────────────
# List + Generate
# ─────────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_my_quizzes(request):
    """GET /api/quiz/  — quizzes the user has generated."""
    qs = (GeneratedQuiz.objects
          .filter(user=request.user)
          .prefetch_related("attempts")
          .order_by("-created_at"))
    subject = request.query_params.get("subject", "").strip()
    if subject:
        qs = qs.filter(subject__iexact=subject)
    return Response(QuizListItemSerializer(qs, many=True).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def generate_quiz(request):
    """
    POST /api/quiz/generate/

    Body:
      {
        "material_id":     "<SavedMaterial uuid>",   # required
        "subject":         "Mathematics",            # optional override
        "num_questions":   10,                       # 3..25
        "difficulty":      "easy" | "medium" | "hard" | "mixed",
        "question_types":  ["mcq","true_false","short"]   # optional
      }

    The backend pulls the file straight from material.file_url, extracts
    the text from the PDF/DOCX, and calls OpenAI. The user never sees
    or pastes the document content.
    """
    # ── Rate limit ────────────────────────────────────────
    since = timezone.now() - timedelta(hours=24)
    recent_count = GeneratedQuiz.objects.filter(
        user=request.user, created_at__gte=since).count()
    if recent_count >= DAILY_GEN_LIMIT:
        return Response(
            {"error": f"You've hit the daily limit of {DAILY_GEN_LIMIT} "
                       "quizzes. Try again tomorrow."},
            status=status.HTTP_429_TOO_MANY_REQUESTS)

    # ── Resolve material ──────────────────────────────────
    material_id = request.data.get("material_id")
    if not material_id:
        return Response({"error": "material_id is required."}, status=400)
    try:
        material = SavedMaterial.objects.get(id=material_id, user=request.user)
    except SavedMaterial.DoesNotExist:
        return Response({"error": "Material not found in your library."}, status=404)

    if not material.file_url:
        return Response(
            {"error": "This saved material has no associated file URL."},
            status=400)

    # ── Inputs ────────────────────────────────────────────
    subject       = (request.data.get("subject") or material.subject or "").strip()
    num_questions = request.data.get("num_questions", 10)
    difficulty    = request.data.get("difficulty", "medium")
    qtypes        = request.data.get("question_types", []) or []

    # ── Run the AI pipeline ───────────────────────────────
    try:
        result = generate_quiz_from_material(
            file_url=material.file_url,
            file_name=material.file_name,
            file_type=material.file_type,
            subject=subject,
            num_questions=num_questions,
            difficulty=difficulty,
            question_types=qtypes,
        )
    except FileFetchError as e:
        return Response({"error": str(e)}, status=502)
    except ExtractionError as e:
        return Response({"error": str(e)}, status=415)
    except GenerationError as e:
        return Response({"error": str(e)}, status=500)

    # ── Persist ───────────────────────────────────────────
    quiz = GeneratedQuiz.objects.create(
        user=request.user,
        material=material,
        title=material.title or material.file_name or "Untitled Quiz",
        subject=subject,
        difficulty=difficulty if difficulty in
                   dict(GeneratedQuiz.Difficulty.choices) else "medium",
        num_questions=len(result["questions"]),
        question_types=qtypes,
        questions=result["questions"],
        tokens_used=result["tokens_used"],
        model_name=result["model_name"],
    )
    return Response(QuizPlaySerializer(quiz).data, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────
# Play + Submit
# ─────────────────────────────────────────────────────────────

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def quiz_play(request, quiz_id):
    """GET /api/quiz/<id>/play/ — questions WITHOUT answers, for taking."""
    try:
        quiz = GeneratedQuiz.objects.get(id=quiz_id, user=request.user)
    except GeneratedQuiz.DoesNotExist:
        return Response({"error": "Quiz not found."}, status=404)
    return Response(QuizPlaySerializer(quiz).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def submit_attempt(request, quiz_id):
    """
    POST /api/quiz/<id>/submit/

    Body:
      {
        "answers":          { "q1": "B", "q2": true, "q3": "..." },
        "duration_seconds": 142
      }

    Grading happens server-side so the client can never fake a score.
    """
    try:
        quiz = GeneratedQuiz.objects.get(id=quiz_id, user=request.user)
    except GeneratedQuiz.DoesNotExist:
        return Response({"error": "Quiz not found."}, status=404)

    answers   = request.data.get("answers") or {}
    duration  = int(request.data.get("duration_seconds") or 0)
    if not isinstance(answers, dict):
        return Response({"error": "`answers` must be an object."}, status=400)

    correct, total, breakdown = grade_attempt(quiz.questions, answers)
    pct = round((correct / total) * 100, 1) if total else 0.0

    attempt = QuizAttempt.objects.create(
        quiz=quiz, user=request.user,
        answers=answers, score=correct, total=total,
        percentage=pct, duration_seconds=duration,
    )

    return Response({
        **QuizAttemptSerializer(attempt).data,
        "breakdown": breakdown,
        "questions": quiz.questions,   # full questions (with correct answers)
    }, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────
# Detail + Delete
# ─────────────────────────────────────────────────────────────

@api_view(["GET", "DELETE"])
@permission_classes([IsAuthenticated])
def quiz_detail(request, quiz_id):
    """GET/DELETE /api/quiz/<id>/"""
    try:
        quiz = GeneratedQuiz.objects.get(id=quiz_id, user=request.user)
    except GeneratedQuiz.DoesNotExist:
        return Response({"error": "Quiz not found."}, status=404)

    if request.method == "DELETE":
        quiz.delete()
        return Response({"success": True})

    return Response(QuizDetailSerializer(quiz).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def quiz_attempts(request, quiz_id):
    """GET /api/quiz/<id>/attempts/  — history for one quiz."""
    try:
        quiz = GeneratedQuiz.objects.get(id=quiz_id, user=request.user)
    except GeneratedQuiz.DoesNotExist:
        return Response({"error": "Quiz not found."}, status=404)
    return Response(QuizAttemptSerializer(
        quiz.attempts.all().order_by("-completed_at"), many=True).data)