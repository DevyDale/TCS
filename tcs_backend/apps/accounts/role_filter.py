# apps/accounts/role_filter.py
"""
Role-based visibility for TCS.

Students and teaching staff see separate feeds and cannot follow each
other. Clubs are the shared community space — visible to both roles.
"""
from django.db.models import Q
from rest_framework import status
from rest_framework.response import Response


def filter_posts_by_role(qs, user):
    """Own posts + same-role posts + any club post."""
    return qs.filter(
        Q(author=user) | Q(author__role=user.role) | Q(club__isnull=False)
    )


def filter_users_by_role(qs, user):
    """Same-role peers only, excluding self."""
    return qs.filter(role=user.role).exclude(id=user.id)


def can_follow(follower, target):
    if follower.id == target.id:
        return False, "You cannot follow yourself."
    if follower.role != target.role:
        return False, "Students and teaching staff cannot follow each other on TCS."
    return True, None


def cross_role_post_404(post, user):
    if post.club is not None:
        return None
    if post.author_id == user.id:
        return None
    if post.author.role == user.role:
        return None
    return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
