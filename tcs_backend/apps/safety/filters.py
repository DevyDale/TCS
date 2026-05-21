"""
Lightweight objectionable-content filter for user-generated text.

This is the "method for filtering objectionable content" required by App
Store Review Guideline 1.2. It runs on every post (and can be wired into
comments) at create time: matched text causes the post to be auto-flagged
(``Post.is_flagged = True``) and opens a ``Report(reason='auto_filter')``
so the item is held out of feeds and surfaces in the moderation queue
until a human clears it.

The term list is intentionally small, conservative, and easy to extend.
For production you'll likely back this with a managed list (a DB table or
a third-party service); the public ``scan()`` / ``is_objectionable()``
signatures stay the same so callers don't change.
"""
import re

# Lowercase, matched on word boundaries. Extend with campus-specific
# terms as needed. Multi-word entries (e.g. "kill yourself") are matched
# as phrases.
_BLOCKED_TERMS = {
    # hate speech / slurs (representative starter set — expand for prod)
    "nigger", "nigga", "faggot", "fag", "tranny", "kike", "spic", "chink",
    "retard", "retarded",
    # threats / violence
    "kill yourself", "kys", "i will kill you",
    # sexual violence
    "rape",
    # explicit profanity (basic)
    "cunt",
}

# Single compiled pattern, longest terms first so phrases win over words.
_PATTERN = re.compile(
    r"\b(" + "|".join(
        re.escape(t) for t in sorted(_BLOCKED_TERMS, key=len, reverse=True)
    ) + r")\b",
    re.IGNORECASE,
)


def scan(text: str):
    """
    Returns ``(is_objectionable: bool, matches: list[str])``.
    Blank or empty text is always clean.
    """
    if not text or not text.strip():
        return False, []
    seen = []
    for m in _PATTERN.findall(text):
        ml = m.lower()
        if ml not in seen:
            seen.append(ml)
    return (len(seen) > 0), seen


def is_objectionable(text: str) -> bool:
    flagged, _ = scan(text)
    return flagged
