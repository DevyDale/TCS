# apps/arcade/services.py
#
# All wallet operations route through THIS module. No view code should
# ever do `user.tokens += x` directly. Every wallet write must:
#   1. happen inside transaction.atomic()
#   2. write a TokenLedger row alongside the balance change
#
# Public functions:
#   • adjust_wallet(user, delta, reason, ...) — low-level signed adjust
#   • debit  (user, amount, reason, ...)      — convenience: negative
#   • credit (user, amount, reason, ...)      — convenience: positive
#   • escrow_wager(user, amount, invite)
#   • refund_wager(user, amount, invite)
#   • payout_winner(winner, amount, session)
#   • transfer(sender, recipient, amount, note)
#   • settle_match(session, scores: {user_id: score}, ...)
#
# Errors raise InsufficientTokens, TransferLimitExceeded, etc.
# These are caught in views and returned as 400/403 responses.

import datetime
import uuid as _uuid

from django.conf       import settings
from django.db         import transaction
from django.db.models  import F, Sum, Q
from django.utils      import timezone
from django.contrib.auth import get_user_model

from .models import (
    Game, GameInvite, GameRequest, GameSession,
    SessionPlayer, TokenLedger, TokenTransfer,
)

User = get_user_model()


# ─────────────────────────────────────────────────────────────
# Errors
# ─────────────────────────────────────────────────────────────
class WalletError(Exception):
    """Base."""

class InsufficientTokens(WalletError):
    pass

class TransferLimitExceeded(WalletError):
    pass

class InvalidRecipient(WalletError):
    pass

class MatchAlreadySettled(WalletError):
    pass


# ─────────────────────────────────────────────────────────────
# Caps / config (tweak in settings.py if you want)
# ─────────────────────────────────────────────────────────────
MAX_DAILY_TRANSFER_OUT     = getattr(settings, "ARCADE_MAX_DAILY_TRANSFER_OUT", 500)
MAX_TRANSFER_PER_TX        = getattr(settings, "ARCADE_MAX_TRANSFER_PER_TX",    200)
MIN_TRANSFER_AMOUNT        = getattr(settings, "ARCADE_MIN_TRANSFER_AMOUNT",    1)
MAX_WAGER                  = getattr(settings, "ARCADE_MAX_WAGER",              500)
MAX_INVITE_RECIPIENTS      = getattr(settings, "ARCADE_MAX_INVITE_RECIPIENTS",  4)
MAX_PENDING_INVITES_SENT   = getattr(settings, "ARCADE_MAX_PENDING_INVITES",    5)


# ─────────────────────────────────────────────────────────────
# Core wallet primitives
# ─────────────────────────────────────────────────────────────
@transaction.atomic
def adjust_wallet(user, delta: int, reason: str, *,
                  reference_type: str = "",
                  reference_id:   str = "",
                  note:           str = "") -> int:
    """Atomically apply `delta` to user.tokens and write a ledger row.

    Locks the user row for the duration of the transaction so concurrent
    writes can't race. Returns the new balance.

    Raises InsufficientTokens if delta < 0 and balance would go negative.
    """
    # SELECT … FOR UPDATE on the user row
    locked = User.objects.select_for_update().get(pk=user.pk)
    new_balance = locked.tokens + delta
    if new_balance < 0:
        raise InsufficientTokens(
            f"Need {-delta} tokens, you have {locked.tokens}.")

    locked.tokens = new_balance
    locked.save(update_fields=["tokens"])

    TokenLedger.objects.create(
        user           = locked,
        delta          = delta,
        balance_after  = new_balance,
        reason         = reason,
        reference_type = reference_type,
        reference_id   = str(reference_id) if reference_id else "",
        note           = note[:140],
    )
    # Keep the live `user` object in sync so callers see the new value
    user.tokens = new_balance
    return new_balance


def debit(user, amount: int, reason: str, **kw) -> int:
    if amount <= 0:
        raise ValueError("debit amount must be > 0")
    return adjust_wallet(user, -amount, reason, **kw)


def credit(user, amount: int, reason: str, **kw) -> int:
    if amount <= 0:
        raise ValueError("credit amount must be > 0")
    return adjust_wallet(user, amount, reason, **kw)


# ─────────────────────────────────────────────────────────────
# Wager escrow / refund
# ─────────────────────────────────────────────────────────────
def escrow_wager(user, amount: int, invite: GameInvite) -> int:
    """Pull `amount` tokens out of the user's wallet for a pending wager."""
    return debit(
        user, amount,
        TokenLedger.Reason.WAGER_ESCROW,
        reference_type="GameInvite",
        reference_id=invite.id,
        note=f"Wager for {invite.game.name}",
    )


def refund_wager(user, amount: int, invite: GameInvite,
                 note: str = "Wager refunded") -> int:
    return credit(
        user, amount,
        TokenLedger.Reason.WAGER_REFUND,
        reference_type="GameInvite",
        reference_id=invite.id,
        note=note,
    )


def payout_winner(winner, amount: int, session: GameSession) -> int:
    return credit(
        winner, amount,
        TokenLedger.Reason.MATCH_WIN,
        reference_type="GameSession",
        reference_id=session.id,
        note=f"Won {session.game_slug}",
    )


# ─────────────────────────────────────────────────────────────
# Peer-to-peer transfer
# ─────────────────────────────────────────────────────────────
@transaction.atomic
def transfer(sender, recipient, amount: int, note: str = "") -> TokenTransfer:
    """Move `amount` tokens from sender → recipient. Atomic + audited."""
    if sender.pk == recipient.pk:
        raise InvalidRecipient("You can't transfer tokens to yourself.")
    if amount < MIN_TRANSFER_AMOUNT:
        raise ValueError(f"Minimum transfer is {MIN_TRANSFER_AMOUNT} tokens.")
    if amount > MAX_TRANSFER_PER_TX:
        raise TransferLimitExceeded(
            f"Max {MAX_TRANSFER_PER_TX} tokens per transfer.")

    # Daily outbound cap
    today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)
    sent_today = (
        TokenTransfer.objects
        .filter(sender=sender, created_at__gte=today_start)
        .aggregate(total=Sum("amount"))["total"] or 0
    )
    if sent_today + amount > MAX_DAILY_TRANSFER_OUT:
        remaining = max(0, MAX_DAILY_TRANSFER_OUT - sent_today)
        raise TransferLimitExceeded(
            f"Daily transfer cap is {MAX_DAILY_TRANSFER_OUT} tokens. "
            f"You have {remaining} left today.")

    # Create the transfer record first so we have a stable id for the ledger refs
    tx = TokenTransfer.objects.create(
        sender=sender, recipient=recipient, amount=amount, note=note[:140],
    )
    # Two ledger rows + two balance changes (debit then credit)
    debit(
        sender, amount,
        TokenLedger.Reason.TRANSFER_OUT,
        reference_type="TokenTransfer", reference_id=tx.id,
        note=f"To @{recipient.gamer_tag or recipient.user_id}: {note}"[:140],
    )
    credit(
        recipient, amount,
        TokenLedger.Reason.TRANSFER_IN,
        reference_type="TokenTransfer", reference_id=tx.id,
        note=f"From @{sender.gamer_tag or sender.user_id}: {note}"[:140],
    )
    return tx


# ─────────────────────────────────────────────────────────────
# Invite creation
# ─────────────────────────────────────────────────────────────
@transaction.atomic
def create_invite(sender, game: Game, wager: int,
                  recipients: list, expires_minutes: int = 30):
    """Create a GameInvite + child GameRequest rows; escrow sender's wager.

    `recipients` is a list of User objects.
    """
    if game.invite_mode == Game.InviteMode.SOLO_ONLY:
        raise ValueError("This game doesn't support challenges.")
    if not recipients:
        raise ValueError("No recipients selected.")
    if len(recipients) > MAX_INVITE_RECIPIENTS:
        raise ValueError(f"Max {MAX_INVITE_RECIPIENTS} recipients.")
    if wager < 0 or wager > MAX_WAGER:
        raise ValueError(f"Wager must be between 0 and {MAX_WAGER}.")
    # multi-recipient only allowed for royale
    if len(recipients) > 1 and game.invite_mode != Game.InviteMode.ROYALE:
        raise ValueError(f"{game.name} only supports 1-on-1 challenges.")
    # no duplicates, no self
    rcpt_ids = set()
    for r in recipients:
        if r.pk == sender.pk:
            raise InvalidRecipient("You can't challenge yourself.")
        if r.pk in rcpt_ids:
            raise InvalidRecipient("Duplicate recipient.")
        rcpt_ids.add(r.pk)
    # Pending invites cap
    open_invites = GameInvite.objects.filter(
        sender=sender, status="pending").count()
    if open_invites >= MAX_PENDING_INVITES_SENT:
        raise ValueError(
            f"You have {open_invites} pending challenges. "
            f"Cancel some before sending more.")

    invite = GameInvite.objects.create(
        sender      = sender,
        game        = game,
        wager       = wager,
        invite_mode = game.invite_mode,
        expires_at  = timezone.now() + datetime.timedelta(minutes=expires_minutes),
    )
    # Escrow sender's wager up-front
    if wager > 0:
        escrow_wager(sender, wager, invite)

    # Per-recipient rows (legacy fields populated for compatibility)
    requests = []
    for r in recipients:
        gr = GameRequest.objects.create(
            invite      = invite,
            sender      = sender,
            receiver    = r,
            game_slug   = game.slug,
            game_name   = game.name,
            wager       = wager,
            status      = "pending",
            paid        = False,
            expires_at  = invite.expires_at,
        )
        requests.append(gr)

    return invite, requests


# ─────────────────────────────────────────────────────────────
# Accept / Decline
# ─────────────────────────────────────────────────────────────
@transaction.atomic
def accept_request(request_row: GameRequest, user) -> GameSession:
    """Accept a pending GameRequest. Escrows recipient's wager.

    For first-come games: locks the invite, auto-declines siblings.
    For royale games:    adds player to lobby; first acceptance starts session.
    """
    if request_row.receiver_id != user.pk:
        raise PermissionError("This request isn't for you.")
    # Re-lock to avoid race
    gr = (GameRequest.objects.select_for_update()
          .select_related("invite", "invite__game")
          .get(pk=request_row.pk))

    if gr.status != "pending":
        raise ValueError(f"Already {gr.status}.")
    invite = gr.invite
    if invite is None:
        raise ValueError("Legacy request without invite — accept via legacy path.")
    if invite.status not in ("pending", "started"):
        raise ValueError(f"Invite is {invite.status}.")
    if invite.is_expired:
        raise ValueError("Invite has expired.")

    # Escrow recipient's wager
    if invite.wager > 0:
        escrow_wager(user, invite.wager, invite)

    gr.status       = "accepted"
    gr.paid         = True
    gr.responded_at = timezone.now()
    gr.save(update_fields=["status", "paid", "responded_at"])

    game = invite.game
    if game.invite_mode == Game.InviteMode.FIRST_COME:
        # Lock: auto-decline all OTHER pending siblings, refund nothing
        # (only the accepter paid, sender's escrow stays)
        siblings = GameRequest.objects.select_for_update().filter(
            invite=invite, status="pending").exclude(pk=gr.pk)
        for s in siblings:
            s.status = "auto_declined"
            s.responded_at = timezone.now()
            s.save(update_fields=["status", "responded_at"])

        session = _create_session(invite, [invite.sender, user])
        invite.status = "started"
        invite.save(update_fields=["status"])
        return session

    elif game.invite_mode == Game.InviteMode.ROYALE:
        # Either there's an existing session in 'waiting' status, or we create one.
        session = (GameSession.objects.select_for_update()
                   .filter(invite=invite).first())
        if session is None:
            session = _create_session(invite, [invite.sender, user],
                                      status="waiting")
            invite.status = "started"
            invite.save(update_fields=["status"])
        else:
            # Add this player as a participant
            SessionPlayer.objects.get_or_create(
                session=session, user=user,
                defaults={"wager_paid": invite.wager},
            )
        return session

    else:
        raise ValueError("Game not multiplayer.")


@transaction.atomic
def decline_request(request_row: GameRequest, user):
    if request_row.receiver_id != user.pk:
        raise PermissionError("This request isn't for you.")
    gr = GameRequest.objects.select_for_update().get(pk=request_row.pk)
    if gr.status != "pending":
        raise ValueError(f"Already {gr.status}.")
    gr.status       = "declined"
    gr.responded_at = timezone.now()
    gr.save(update_fields=["status", "responded_at"])

    invite = gr.invite
    if invite is None:
        return  # legacy
    # If ALL recipients have declined / expired, refund sender and cancel invite.
    still_open = GameRequest.objects.filter(
        invite=invite, status="pending").exists()
    any_accepted = GameRequest.objects.filter(
        invite=invite, status="accepted").exists()
    if not still_open and not any_accepted:
        if invite.wager > 0:
            refund_wager(invite.sender, invite.wager, invite,
                         note="All recipients declined")
        invite.status = "cancelled"
        invite.save(update_fields=["status"])


# ─────────────────────────────────────────────────────────────
# Session helpers
# ─────────────────────────────────────────────────────────────
def _create_session(invite: GameInvite, players: list,
                    status: str = "active") -> GameSession:
    """Internal: build a GameSession from an invite + initial players."""
    game  = invite.game
    pot   = invite.wager * len(players)
    sess  = GameSession.objects.create(
        invite      = invite,
        game        = game,
        request     = None,
        player1     = players[0] if len(players) > 0 else None,
        player2     = players[1] if len(players) > 1 else None,
        game_slug   = game.slug,
        wager       = invite.wager,
        pot         = pot,
        status      = status,
        started_at  = timezone.now() if status == "active" else None,
    )
    # Always create SessionPlayer rows (so royale + 1v1 share the same shape)
    for p in players:
        SessionPlayer.objects.create(
            session=sess, user=p, wager_paid=invite.wager,
        )
    return sess


# ─────────────────────────────────────────────────────────────
# Cancel a sent invite (sender clicks "cancel")
# ─────────────────────────────────────────────────────────────
@transaction.atomic
def cancel_invite(invite: GameInvite, sender):
    if invite.sender_id != sender.pk:
        raise PermissionError("Only the sender can cancel.")
    inv = GameInvite.objects.select_for_update().get(pk=invite.pk)
    if inv.status != "pending":
        raise ValueError(f"Invite is already {inv.status}.")

    # Auto-decline all pending recipient rows
    GameRequest.objects.filter(
        invite=inv, status="pending"
    ).update(status="declined", responded_at=timezone.now())

    if inv.wager > 0:
        refund_wager(inv.sender, inv.wager, inv, note="Cancelled by sender")
    inv.status = "cancelled"
    inv.save(update_fields=["status"])


# ─────────────────────────────────────────────────────────────
# Expire stale invites (called by a periodic task or on read)
# ─────────────────────────────────────────────────────────────
def expire_stale_invites():
    """Refund + cancel any invite that's past its expires_at."""
    now = timezone.now()
    stale = GameInvite.objects.filter(status="pending", expires_at__lt=now)
    for inv in stale:
        with transaction.atomic():
            inv = GameInvite.objects.select_for_update().get(pk=inv.pk)
            if inv.status != "pending":
                continue
            GameRequest.objects.filter(
                invite=inv, status="pending"
            ).update(status="expired", responded_at=now)
            if inv.wager > 0:
                refund_wager(inv.sender, inv.wager, inv, note="Invite expired")
            inv.status = "expired"
            inv.save(update_fields=["status"])


# ─────────────────────────────────────────────────────────────
# Match settlement
# ─────────────────────────────────────────────────────────────
@transaction.atomic
def settle_match(session: GameSession,
                 player_scores: dict,
                 forfeited_by: list = None) -> dict:
    """Mark the session complete, declare a winner, and pay out the pot.

    `player_scores` = {user_pk: int_score}
    `forfeited_by`  = list of user_pks who forfeited (lose automatically)
    Returns dict summarising payout.
    """
    forfeited_by = set(forfeited_by or [])

    sess = (GameSession.objects.select_for_update()
            .select_related("invite", "game")
            .get(pk=session.pk))
    if sess.status == "completed":
        raise MatchAlreadySettled("Already settled.")

    # Update SessionPlayer rows
    participants = list(sess.participants.select_for_update().all())
    if not participants:
        raise ValueError("No participants on this session.")

    for sp in participants:
        sp.score      = int(player_scores.get(sp.user_id, sp.score))
        sp.forfeited  = sp.user_id in forfeited_by
        sp.finished_at= timezone.now()
        sp.save(update_fields=["score", "forfeited", "finished_at"])

    # Winner = highest score among non-forfeited; tiebreak = first finisher
    eligible = [sp for sp in participants if not sp.forfeited]
    winner_sp = None
    if eligible:
        eligible.sort(key=lambda sp: (-sp.score, sp.joined_at))
        top_score = eligible[0].score
        # Detect tie
        tied = [sp for sp in eligible if sp.score == top_score]
        if len(tied) == 1:
            winner_sp = tied[0]

    # Assign placements
    ranked = sorted(participants, key=lambda sp: (sp.forfeited,
                                                  -sp.score, sp.joined_at))
    for i, sp in enumerate(ranked):
        sp.placement = i + 1
        sp.save(update_fields=["placement"])

    pot = sess.pot
    payout_summary = {"pot": pot, "winner": None, "draw": False, "settled": []}

    if winner_sp is not None:
        winner = winner_sp.user
        if pot > 0:
            payout_winner(winner, pot, sess)
        sess.winner = winner
        payout_summary["winner"] = str(winner.pk)
    else:
        # Draw: refund every non-forfeited player their wager
        payout_summary["draw"] = True
        if pot > 0:
            for sp in eligible:
                refund_wager(sp.user, sp.wager_paid, sess.invite,
                             note="Match drawn — wager refunded")

    sess.status   = "completed"
    sess.ended_at = timezone.now()
    # Legacy 1v1 score mirrors
    if sess.player1_id and sess.player2_id:
        sess.p1_score = int(player_scores.get(sess.player1_id, 0))
        sess.p2_score = int(player_scores.get(sess.player2_id, 0))
    sess.save(update_fields=["status", "winner", "ended_at",
                             "p1_score", "p2_score"])

    if sess.invite_id:
        GameInvite.objects.filter(pk=sess.invite_id).update(status="completed")

    payout_summary["settled"] = [
        {"user_id": str(sp.user_id), "score": sp.score,
         "placement": sp.placement, "forfeited": sp.forfeited}
        for sp in participants
    ]
    return payout_summary


# ─────────────────────────────────────────────────────────────
# Solo win reward (replaces the old inline math in submit_score)
# ─────────────────────────────────────────────────────────────
def solo_reward(user, game: Game, score: int, bonus_tokens: int = 0) -> dict:
    """Award tokens for a solo play. Performance-scaled."""
    bonus_tokens = max(0, min(30, int(bonus_tokens)))
    perf_bonus   = min(score // 100, 50)
    total        = game.token_reward + perf_bonus + bonus_tokens
    if total > 0:
        credit(
            user, total,
            TokenLedger.Reason.SOLO_WIN,
            reference_type="Game", reference_id=game.id,
            note=f"Solo {game.name}",
        )
    return {
        "tokens_earned": total,
        "breakdown": {
            "base":        game.token_reward,
            "performance": perf_bonus,
            "bonus":       bonus_tokens,
        },
    }