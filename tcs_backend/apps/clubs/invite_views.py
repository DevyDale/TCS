"""Club invite flow: send / accept / decline.

POST /api/clubs/<club_id>/send-invite/   body: {user_id: <uuid>}
POST /api/clubs/invites/<invite_id>/accept/
POST /api/clubs/invites/<invite_id>/decline/

Each send creates a ClubInvite + a Notification for the recipient.
Accept creates a ClubMember row and marks the invite accepted.
Decline just marks it declined.
"""
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.clubs.models import Club, ClubMember, ClubInvite
from apps.notifications.models import Notification


def _can_invite(club, user):
    """Only club admins (president / executive / admin) can send invites."""
    return ClubMember.objects.filter(
        club=club, user=user, status='active',
        role__in=['president', 'executive', 'admin'],
    ).exists()


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def send_club_invite(request, pk):
    try:
        club = Club.objects.get(pk=pk)
    except Club.DoesNotExist:
        return Response({"error": "Club not found."}, status=404)

    if not _can_invite(club, request.user):
        return Response(
            {"error": "Only club admins can invite members."}, status=403)

    user_id = request.data.get('user_id')
    if not user_id:
        return Response({"error": "user_id is required."}, status=400)

    User = get_user_model()
    try:
        recipient = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({"error": "User not found."}, status=404)

    if recipient.pk == request.user.pk:
        return Response({"error": "You can't invite yourself."}, status=400)

    if ClubMember.objects.filter(
            club=club, user=recipient, status='active').exists():
        return Response({"error": "Already a member."}, status=400)

    if ClubInvite.objects.filter(
            club=club, recipient=recipient, status='pending').exists():
        return Response({"error": "Already invited."}, status=400)

    invite = ClubInvite.objects.create(
        club=club, sender=request.user, recipient=recipient,
    )

    sender_name = (getattr(request.user, 'display_name', '')
                   or getattr(request.user, 'username', '')
                   or 'Someone')
    Notification.objects.create(
        recipient=recipient,
        actor=request.user,
        notif_type='club_invite',
        title=f'Invited to {club.name}',
        body=f'{sender_name} invited you to join {club.name}.',
        target_type='club_invite',
        target_id=str(invite.id),
    )
    return Response({
        'success': True,
        'invite_id': str(invite.id),
        'recipient_id': str(recipient.pk),
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def accept_club_invite(request, invite_id):
    try:
        invite = ClubInvite.objects.select_related('club').get(pk=invite_id)
    except ClubInvite.DoesNotExist:
        return Response({"error": "Invite not found."}, status=404)
    if invite.recipient_id != request.user.pk:
        return Response({"error": "This invite isn't for you."}, status=403)
    if invite.status != 'pending':
        return Response({"error": f"Already {invite.status}."}, status=400)

    ClubMember.objects.get_or_create(
        club=invite.club, user=request.user,
        defaults={'status': 'active', 'role': 'member'},
    )
    invite.status = 'accepted'
    invite.responded_at = timezone.now()
    invite.save(update_fields=['status', 'responded_at'])

    invite.club.members_count = ClubMember.objects.filter(
        club=invite.club, status='active').count()
    invite.club.save(update_fields=['members_count'])

    Notification.objects.filter(
        recipient=request.user,
        notif_type='club_invite',
        target_id=str(invite.id),
    ).update(is_read=True)

    return Response({
        'success': True,
        'club_id': str(invite.club.id),
        'club_name': invite.club.name,
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def decline_club_invite(request, invite_id):
    try:
        invite = ClubInvite.objects.get(pk=invite_id)
    except ClubInvite.DoesNotExist:
        return Response({"error": "Invite not found."}, status=404)
    if invite.recipient_id != request.user.pk:
        return Response({"error": "This invite isn't for you."}, status=403)
    if invite.status != 'pending':
        return Response({"error": f"Already {invite.status}."}, status=400)
    invite.status = 'declined'
    invite.responded_at = timezone.now()
    invite.save(update_fields=['status', 'responded_at'])

    Notification.objects.filter(
        recipient=request.user,
        notif_type='club_invite',
        target_id=str(invite.id),
    ).update(is_read=True)
    return Response({'success': True})
