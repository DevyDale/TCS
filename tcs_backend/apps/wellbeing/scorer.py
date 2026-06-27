# apps/wellbeing/scorer.py
#
# Fast, deterministic wellbeing scorer. Keyword/lexicon pass over a student
# message — sub-millisecond, no API call. Returns a tier + risk score + theme
# tags + a redacted snippet. A model pass can be layered on later; this is the
# always-on first stage. The AI is a TRIAGE SIGNAL, never a clinician.

import re

# Crisis / self-harm — highest weight. Tuned conservatively; staff review every flag.
_CRISIS = [
    "kill myself", "want to die", "end my life", "suicid", "self harm",
    "self-harm", "cut myself", "hurt myself", "no reason to live",
    "better off dead", "can't go on", "cant go on", "overdose",
]
_ACUTE = [
    "hopeless", "worthless", "can't cope", "cant cope", "breaking down",
    "panic attack", "i give up", "hate myself", "so alone", "nobody cares",
    "crying every", "can't sleep", "cant sleep", "scared", "terrified",
]
_DISTRESS = [
    "stressed", "anxious", "anxiety", "depress", "overwhelm", "exhausted",
    "burnt out", "burnout", "homesick", "lonely", "struggling", "failing",
    "can't focus", "cant focus", "miss home",
]

_THEMES = {
    "academic":      ["exam", "assignment", "study", "grade", "fail", "deadline", "class"],
    "homesickness":  ["homesick", "miss home", "family", "back home", "lonely", "alone"],
    "financial":     ["money", "rent", "afford", "fees", "broke", "tuition", "job"],
    "accommodation": ["accommodation", "housing", "landlord", "roommate", "flat", "dorm"],
    "visa":          ["visa", "immigration", "deport", "passport", "permit"],
    "social":        ["friends", "bullied", "bully", "argument", "fight", "left out"],
    "health":        ["sick", "ill", "sleep", "tired", "eating", "doctor"],
}


def _has(text, words):
    return any(w in text for w in words)


def _snippet(message, max_len=160):
    s = re.sub(r"\s+", " ", (message or "")).strip()
    return (s[:max_len] + "…") if len(s) > max_len else s


def score_message(message):
    """Return {tier, risk_score, themes, severe, severity, reason, snippet}."""
    t = (message or "").lower()
    themes = [name for name, words in _THEMES.items() if _has(t, words)]

    if _has(t, _CRISIS):
        return {
            "tier": "at_risk", "risk_score": 0.95, "themes": themes,
            "severe": True, "severity": "critical",
            "reason": "Language indicating possible self-harm or crisis.",
            "snippet": _snippet(message),
        }
    acute_hits = sum(1 for w in _ACUTE if w in t)
    if acute_hits >= 2 or (acute_hits >= 1 and _has(t, _DISTRESS)):
        return {
            "tier": "at_risk", "risk_score": 0.8, "themes": themes,
            "severe": True, "severity": "high",
            "reason": "Multiple acute-distress markers detected.",
            "snippet": _snippet(message),
        }
    if acute_hits >= 1:
        return {
            "tier": "struggling", "risk_score": 0.65, "themes": themes,
            "severe": True, "severity": "watch",
            "reason": "An acute-distress marker detected.",
            "snippet": _snippet(message),
        }
    distress_hits = sum(1 for w in _DISTRESS if w in t)
    if distress_hits >= 2:
        return {"tier": "struggling", "risk_score": 0.55, "themes": themes,
                "severe": False, "severity": None, "reason": "", "snippet": ""}
    if distress_hits >= 1:
        return {"tier": "okay", "risk_score": 0.4, "themes": themes,
                "severe": False, "severity": None, "reason": "", "snippet": ""}
    return {"tier": "thriving", "risk_score": 0.1, "themes": themes,
            "severe": False, "severity": None, "reason": "", "snippet": ""}


def record_signal(student, message):
    """Score + persist a signal; raise a Case if severe. Best-effort, never
    raises into the chat path. Gated by settings.WELLBEING_SCORING_ENABLED."""
    from django.conf import settings
    # Two consent gates, both must pass: the school-level switch AND the
    # student's own choice. Either off → no message is ever scored or stored.
    if not getattr(settings, "WELLBEING_SCORING_ENABLED", False):
        return None
    if getattr(student, "wellbeing_opt_out", False):
        return None
    try:
        from .models import WellbeingSignal, WellbeingCase
        r = score_message(message)
        sig = WellbeingSignal.objects.create(
            student=student, tier=r["tier"], risk_score=r["risk_score"],
            themes=r["themes"], snippet=r["snippet"])
        if r["severe"]:
            WellbeingCase.objects.create(
                signal=sig, student=student, severity=r["severity"],
                ai_reason=r["reason"])
        return sig
    except Exception:
        import logging
        logging.getLogger(__name__).exception("wellbeing record_signal failed")
        return None
