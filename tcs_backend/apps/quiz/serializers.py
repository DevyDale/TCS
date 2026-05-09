# apps/quiz/serializers.py
from rest_framework import serializers

from .models import GeneratedQuiz, QuizAttempt


class QuizListItemSerializer(serializers.ModelSerializer):
    """Compact card representation for the saved-quizzes list."""
    question_count = serializers.SerializerMethodField()
    last_score     = serializers.SerializerMethodField()
    attempt_count  = serializers.SerializerMethodField()

    class Meta:
        model  = GeneratedQuiz
        fields = ["id", "title", "subject", "difficulty",
                  "question_count", "last_score", "attempt_count",
                  "created_at"]

    def get_question_count(self, obj):
        return len(obj.questions or [])

    def get_attempt_count(self, obj):
        return obj.attempts.count()

    def get_last_score(self, obj):
        last = obj.attempts.order_by("-completed_at").first()
        if not last:
            return None
        return {"score": last.score, "total": last.total,
                "percentage": last.percentage}


class QuizPlaySerializer(serializers.ModelSerializer):
    """
    Returned when the user opens a quiz to take it.
    Strips correct_answer / explanation from each question so they aren't
    leaked over the wire while the quiz is in progress.
    """
    questions = serializers.SerializerMethodField()

    class Meta:
        model  = GeneratedQuiz
        fields = ["id", "title", "subject", "difficulty",
                  "num_questions", "questions", "created_at"]

    def get_questions(self, obj):
        safe = []
        for q in obj.questions or []:
            item = {
                "id":       q.get("id"),
                "type":     q.get("type"),
                "question": q.get("question"),
            }
            if q.get("type") == "mcq":
                item["options"] = q.get("options") or []
            safe.append(item)
        return safe


class QuizDetailSerializer(serializers.ModelSerializer):
    """Full quiz including answers — only used after grading."""
    class Meta:
        model  = GeneratedQuiz
        fields = ["id", "title", "subject", "difficulty",
                  "num_questions", "questions", "created_at"]


class QuizAttemptSerializer(serializers.ModelSerializer):
    class Meta:
        model  = QuizAttempt
        fields = ["id", "quiz", "score", "total", "percentage",
                  "duration_seconds", "completed_at"]